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
READ_ONLY="${CURSOR_SUBAGENT_READ_ONLY:-0}"

usage() {
  cat <<'EOF'
Usage: run.sh [--model <alias>] [--cd <dir>] [--resume <session_id>]
              [--timeout <seconds>] [--no-timeout] [--read-only]

Prompt on stdin only.
  --model <alias>       Override model (else SKILL.md / CURSOR_SUBAGENT_MODEL)
  --cd <dir>            Workspace root for the agent CLI (--workspace)
  --resume <session_id> Cold-resume that exact chat (agent -p --resume <id>).
                        Exact id required — never bare --resume / `agent resume`.
  --timeout <seconds>   Kill the agent CLI after N seconds (exit 124)
  --no-timeout          Wait until the agent CLI finishes (same as --timeout 0)
  --read-only           Not supported: exits 2 before the agent CLI starts
                        (CURSOR_SUBAGENT_READ_ONLY=1)

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
    --read-only)
      READ_ONLY=1
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

if [[ "$READ_ONLY" != 0 && "$READ_ONLY" != 1 ]]; then
  echo "run.sh: invalid read-only value: '$READ_ONLY' (expected 0 or 1)" >&2
  exit 2
fi
# Fail closed: ask mode without --force/--approve-mcps rejects edits, shell, web and
# MCP calls, but the CLI still loads the user's MCP servers, and read-only means none.
if [[ "$READ_ONLY" -eq 1 ]]; then
  echo "run.sh: --read-only is not supported by the Cursor agent CLI (MCP servers still load); use the claude or codex harness" >&2
  exit 2
fi

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

AGENT_BIN=""
if command -v agent >/dev/null 2>&1; then
  AGENT_BIN="$(command -v agent)"
elif command -v cursor-agent >/dev/null 2>&1; then
  AGENT_BIN="$(command -v cursor-agent)"
else
  echo "run.sh: agent/cursor-agent not found on PATH" >&2
  exit 127
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  # `agent status` is the auth probe. Do not call `cursor status` (IDE) or
  # `cursor agent status` (dispatcher prepends a nested `agent` command).
  if ! "$AGENT_BIN" status >/dev/null 2>&1; then
    echo "run.sh: auth required — run 'agent login' or set CURSOR_API_KEY" >&2
    exit 127
  fi
fi

# shellcheck source=/dev/null
source "$SHARED_DIR/setup-live-log.sh" cursor

CURSOR_ARGS=(
  --disable-auto-update
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
  printf '%s' "$PROMPT" | "$AGENT_BIN" "${CURSOR_ARGS[@]}" | python3 "$LIVE_LOG_PY" --harness cursor --log "$LOG_FILE"
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
