#!/usr/bin/env bash
set -euo pipefail

# Defaults SoT = ../SKILL.md table (model / effort). Agent passes --model/--effort
# from that table or user override; if omitted, run.sh parses SKILL.md.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd "$SCRIPT_DIR/.." && pwd)/SKILL.md"
SHARED_DIR="$(cd "$SCRIPT_DIR/../_shared" && pwd)"
# shellcheck source=/dev/null
source "$SHARED_DIR/read-skill-defaults.sh"

DEFAULT_TIMEOUT_SEC=0 # 0 = wait indefinitely; set OPENCODE_SUBAGENT_TIMEOUT or use --timeout

MODEL="${OPENCODE_SUBAGENT_MODEL:-}"
EFFORT="${OPENCODE_SUBAGENT_EFFORT:-}"
TIMEOUT_SEC="${OPENCODE_SUBAGENT_TIMEOUT:-$DEFAULT_TIMEOUT_SEC}"
WORKDIR=""
RESUME_ID=""

usage() {
  cat <<'EOF'
Usage: run.sh [--model <provider/model>] [--effort <level>] --cd <dir>
              [--resume <session_id>] [--timeout <seconds>] [--no-timeout]

Prompt on stdin only.
  --model <provider/model> Override model (else SKILL.md / OPENCODE_SUBAGENT_MODEL)
  --effort <level>        Override effort (else SKILL.md / OPENCODE_SUBAGENT_EFFORT); maps to --variant
  --cd <dir>              Working root for opencode run (--dir); required
  --resume <session_id>   Cold-resume that exact session (`run -s <id>`, ses_… form).
                          Exact id required — never --continue.
  --timeout <seconds>     Kill OpenCode after N seconds (exit 124)
  --no-timeout            Wait until OpenCode finishes (same as --timeout 0)

Live progress: stderr + $TMPDIR/agent-subagent/latest-opencode.log (LOG= path printed early).
Session id: `SESSION=<sessionID>` on stderr + log from the first event.
Stdout: final result text only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --effort)
      EFFORT="$2"
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
if [[ -z "$EFFORT" ]]; then
  EFFORT="$(skill_default "$SKILL_MD" effort)"
fi
if [[ -z "$MODEL" || -z "$EFFORT" ]]; then
  echo "run.sh: missing model/effort — pass --model/--effort or set defaults in $SKILL_MD" >&2
  exit 2
fi
if [[ -z "$WORKDIR" ]]; then
  echo "run.sh: --cd <dir> is required" >&2
  exit 2
fi
if [[ ! -d "$WORKDIR" ]]; then
  echo "run.sh: --cd directory does not exist: $WORKDIR" >&2
  exit 2
fi

PROMPT="$(cat)"
if [[ -z "$PROMPT" ]]; then
  echo "run.sh: prompt required on stdin" >&2
  exit 2
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "run.sh: opencode not found on PATH" >&2
  exit 127
fi

# shellcheck source=/dev/null
source "$SHARED_DIR/setup-live-log.sh" opencode

RESULT_FILE="$(mktemp)"
trap 'rm -f "$RESULT_FILE"' EXIT

OPENCODE_ARGS=(run -m "$MODEL" --variant "$EFFORT" --auto --format json --dir "$WORKDIR")

if [[ -n "$RESUME_ID" ]]; then
  OPENCODE_ARGS+=(-s "$RESUME_ID")
fi

run_pipeline() {
  printf '%s' "$PROMPT" | opencode "${OPENCODE_ARGS[@]}" | python3 "$LIVE_LOG_PY" --harness opencode --log "$LOG_FILE"
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
  echo "run.sh: opencode pipeline failed (exit $EXIT). LOG=$LOG_FILE" >&2
  if [[ -s "$RESULT_FILE" ]]; then
    cat "$RESULT_FILE" >&2
  fi
  exit "$EXIT"
fi

cat "$RESULT_FILE"
if [[ -n "$(tail -c 1 "$RESULT_FILE" 2>/dev/null || true)" ]]; then
  printf '\n'
fi
