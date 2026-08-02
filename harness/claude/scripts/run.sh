#!/usr/bin/env bash
set -euo pipefail

# Defaults SoT = ../SKILL.md table (model / effort / cache_ttl). Agent passes
# overrides from that table or user input; if omitted, run.sh parses SKILL.md.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd "$SCRIPT_DIR/.." && pwd)/SKILL.md"
SHARED_DIR="$(cd "$SCRIPT_DIR/../_shared" && pwd)"
# shellcheck source=/dev/null
source "$SHARED_DIR/read-skill-defaults.sh"

DEFAULT_TIMEOUT_SEC=0 # 0 = wait indefinitely; set CLAUDE_SUBAGENT_TIMEOUT or use --timeout

MODEL="${CLAUDE_SUBAGENT_MODEL:-}"
EFFORT="${CLAUDE_SUBAGENT_EFFORT:-}"
CACHE_TTL="${CLAUDE_SUBAGENT_CACHE_TTL:-}"
CACHE_TTL_FLAG_SET=0
TIMEOUT_SEC="${CLAUDE_SUBAGENT_TIMEOUT:-$DEFAULT_TIMEOUT_SEC}"
RESUME_ID=""

usage() {
  cat <<'EOF'
Usage: run.sh [--model <alias>] [--effort <level>] [--cache-ttl <1h|5m>]
              [--resume <session_id>] [--timeout <seconds>] [--no-timeout]

Prompt on stdin only.
  --model <alias>       Override model (else SKILL.md / CLAUDE_SUBAGENT_MODEL)
  --effort <level>      Override effort (else SKILL.md / CLAUDE_SUBAGENT_EFFORT)
  --cache-ttl <1h|5m>   Override prompt-cache TTL (else SKILL.md /
                        CLAUDE_SUBAGENT_CACHE_TTL)
  --resume <session_id> Cold-resume that exact claude session (-p --resume <id>).
                        Exact id required. Same model/effort/tool flags as fresh.
  --timeout <seconds>   Kill claude after N seconds (exit 124)
  --no-timeout          Wait until claude finishes (same as --timeout 0)

Live progress: stderr + $TMPDIR/agent-subagent/latest-claude.log (LOG= path printed early).
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
    --effort)
      EFFORT="$2"
      shift 2
      ;;
    --cache-ttl)
      CACHE_TTL="$2"
      CACHE_TTL_FLAG_SET=1
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
if [[ -z "$CACHE_TTL" && "$CACHE_TTL_FLAG_SET" -eq 0 ]]; then
  CACHE_TTL="$(skill_default "$SKILL_MD" cache_ttl)"
fi
if [[ -z "$MODEL" || -z "$EFFORT" ]]; then
  echo "run.sh: missing model/effort — pass --model/--effort or set defaults in $SKILL_MD" >&2
  exit 2
fi

case "$CACHE_TTL" in
  1h)
    export ENABLE_PROMPT_CACHING_1H=1
    unset FORCE_PROMPT_CACHING_5M
    ;;
  5m)
    export FORCE_PROMPT_CACHING_5M=1
    unset ENABLE_PROMPT_CACHING_1H
    ;;
  *)
    echo "run.sh: invalid --cache-ttl: '$CACHE_TTL' (expected 1h or 5m)" >&2
    exit 2
    ;;
esac

PROMPT="$(cat)"
if [[ -z "$PROMPT" ]]; then
  echo "run.sh: prompt required on stdin" >&2
  exit 2
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "run.sh: claude not found on PATH" >&2
  exit 127
fi

# shellcheck source=/dev/null
source "$SHARED_DIR/setup-live-log.sh" claude

CLAUDE_ARGS=(
  -p
  --model "$MODEL"
  --effort "$EFFORT"
  --tools default
  --permission-mode bypassPermissions
  --output-format stream-json
  --verbose
)
# No --no-session-persistence: sessions must stay resumable by later stages.

if [[ -n "$RESUME_ID" ]]; then
  CLAUDE_ARGS+=(--resume "$RESUME_ID")
fi

RESULT_FILE="$(mktemp)"
trap 'rm -f "$RESULT_FILE"' EXIT

run_pipeline() {
  # Progress on stderr (live-log); final answer on stdout → RESULT_FILE
  printf '%s' "$PROMPT" | claude "${CLAUDE_ARGS[@]}" | python3 "$LIVE_LOG_PY" --harness claude --log "$LOG_FILE"
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
  echo "run.sh: claude pipeline failed (exit $EXIT). LOG=$LOG_FILE" >&2
  if [[ -s "$RESULT_FILE" ]]; then
    cat "$RESULT_FILE" >&2
  fi
  exit "$EXIT"
fi

cat "$RESULT_FILE"
if [[ -n "$(tail -c 1 "$RESULT_FILE" 2>/dev/null || true)" ]]; then
  printf '\n'
fi
