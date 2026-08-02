#!/usr/bin/env bash
set -euo pipefail

# Defaults SoT = ../SKILL.md table (model). Agent passes --model from that table
# or user override; if omitted, run.sh parses SKILL.md. (No effort flag — slug.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd "$SCRIPT_DIR/.." && pwd)/SKILL.md"
SHARED_DIR="$(cd "$SCRIPT_DIR/../_shared" && pwd)"
# shellcheck source=/dev/null
source "$SHARED_DIR/read-skill-defaults.sh"

DEFAULT_TIMEOUT_SEC=0 # 0 = wait indefinitely; set CURSOR_SUBAGENT_TIMEOUT or use --timeout

MODEL="${CURSOR_SUBAGENT_MODEL:-}"
TIMEOUT_SEC="${CURSOR_SUBAGENT_TIMEOUT:-$DEFAULT_TIMEOUT_SEC}"
WORKDIR=""
RESUME_ID=""

usage() {
  cat <<'EOF'
Usage: run.sh [--model <alias>] [--cd <dir>] [--resume <session_id>]
              [--timeout <seconds>] [--no-timeout]

Prompt on stdin only.
  --model <alias>       Override model (else SKILL.md / CURSOR_SUBAGENT_MODEL)
  --cd <dir>            Workspace root for cursor agent (--workspace)
  --resume <session_id> Cold-resume that exact cursor chat (agent -p --resume <id>).
                        Exact id required — never bare --resume / `agent resume`.
  --timeout <seconds>   Kill cursor agent after N seconds (exit 124)
  --no-timeout          Wait until cursor agent finishes (same as --timeout 0)

Live progress: stderr + $TMPDIR/agent-subagent/latest-cursor.log (LOG= path printed early).
Session id: `SESSION=<session_id>` on stderr + log as soon as system/init arrives.
Stdout: final result text only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --cd)
      WORKDIR="$2"
      shift 2
      ;;
    --resume)
      RESUME_ID="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --no-timeout)
      TIMEOUT_SEC=0
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "run.sh: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  MODEL="$(skill_default "$SKILL_MD" model)"
fi
if [[ -z "$MODEL" ]]; then
  echo "run.sh: missing model — pass --model or set defaults in $SKILL_MD" >&2
  exit 2
fi

PROMPT="$(cat)"
if [[ -z "$PROMPT" ]]; then
  echo "run.sh: prompt required on stdin" >&2
  exit 2
fi

if ! command -v cursor >/dev/null 2>&1; then
  echo "run.sh: cursor not found on PATH" >&2
  exit 127
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  if ! cursor agent status >/dev/null 2>&1; then
    echo "run.sh: auth required — run 'cursor agent login' or set CURSOR_API_KEY" >&2
    exit 127
  fi
fi

# shellcheck source=/dev/null
source "$SHARED_DIR/setup-live-log.sh" cursor

CURSOR_ARGS=(
  agent
  -p
  --model "$MODEL"
  --trust
  --force
  --approve-mcps
  --output-format stream-json
)

if [[ -n "$RESUME_ID" ]]; then
  CURSOR_ARGS+=(--resume "$RESUME_ID")
fi

if [[ -n "$WORKDIR" ]]; then
  CURSOR_ARGS+=(--workspace "$WORKDIR")
fi

RESULT_FILE="$(mktemp)"
trap 'rm -f "$RESULT_FILE"' EXIT

run_pipeline() {
  printf '%s' "$PROMPT" | cursor "${CURSOR_ARGS[@]}" | python3 "$LIVE_LOG_PY" --harness cursor --log "$LOG_FILE"
}

set +e
if [[ "$TIMEOUT_SEC" -eq 0 ]]; then
  run_pipeline >"$RESULT_FILE"
  EXIT=$?
else
  set -m
  run_pipeline >"$RESULT_FILE" &
  CHILD_PID=$!
  ELAPSED=0
  while kill -0 "$CHILD_PID" 2>/dev/null; do
    if [[ "$ELAPSED" -ge "$TIMEOUT_SEC" ]]; then
      kill -TERM -"$CHILD_PID" 2>/dev/null || kill -TERM "$CHILD_PID" 2>/dev/null || true
      wait "$CHILD_PID" 2>/dev/null || true
      echo "run.sh: timed out after ${TIMEOUT_SEC}s (LOG=$LOG_FILE)" >&2
      exit 124
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
  wait "$CHILD_PID"
  EXIT=$?
  set +m
fi
set -e

if [[ "$EXIT" -ne 0 ]]; then
  echo "run.sh: cursor pipeline failed (exit $EXIT). LOG=$LOG_FILE" >&2
  if [[ -s "$RESULT_FILE" ]]; then
    cat "$RESULT_FILE" >&2
  fi
  exit "$EXIT"
fi

cat "$RESULT_FILE"
if [[ -n "$(tail -c 1 "$RESULT_FILE" 2>/dev/null || true)" ]]; then
  printf '\n'
fi
