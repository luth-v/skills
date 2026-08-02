#!/usr/bin/env bash
set -euo pipefail

# Defaults SoT = ../SKILL.md table (model / effort). Agent passes --model/--effort
# from that table or user override; if omitted, run.sh parses SKILL.md.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd "$SCRIPT_DIR/.." && pwd)/SKILL.md"
SHARED_DIR="$(cd "$SCRIPT_DIR/../_shared" && pwd)"
# shellcheck source=/dev/null
source "$SHARED_DIR/read-skill-defaults.sh"

DEFAULT_TIMEOUT_SEC=0 # 0 = wait indefinitely; set CODEX_SUBAGENT_TIMEOUT or use --timeout

MODEL="${CODEX_SUBAGENT_MODEL:-}"
EFFORT="${CODEX_SUBAGENT_EFFORT:-}"
TIMEOUT_SEC="${CODEX_SUBAGENT_TIMEOUT:-$DEFAULT_TIMEOUT_SEC}"
WORKDIR=""
RESUME_ID=""

usage() {
  cat <<'EOF'
Usage: run.sh [--model <alias>] [--effort <level>] [--cd <dir>] [--resume <session_id>]
              [--timeout <seconds>] [--no-timeout]

Prompt on stdin only.
  --model <alias>       Override model (else SKILL.md / CODEX_SUBAGENT_MODEL)
  --effort <level>      Override effort (else SKILL.md / CODEX_SUBAGENT_EFFORT)
  --cd <dir>            Working root for codex exec (-C)
  --resume <session_id> Cold-resume that exact codex session (`codex exec resume`).
                        Exact id required — never --last. Model/effort still applied.
  --timeout <seconds>   Kill codex after N seconds (exit 124)
  --no-timeout          Wait until codex finishes (same as --timeout 0)

Live progress: stderr + $TMPDIR/agent-subagent/latest-codex.log (LOG= path printed early).
Session id: `SESSION=<thread_id>` on stderr + log as soon as codex reports it.
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

PROMPT="$(cat)"
if [[ -z "$PROMPT" ]]; then
  echo "run.sh: prompt required on stdin" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "run.sh: codex not found on PATH" >&2
  exit 127
fi

# shellcheck source=/dev/null
source "$SHARED_DIR/setup-live-log.sh" codex

OUTPUT_MSG_FILE="$(mktemp)"
RESULT_FILE="$(mktemp)"
trap 'rm -f "$OUTPUT_MSG_FILE" "$RESULT_FILE"' EXIT

CODEX_COMMON=(
  -m "$MODEL"
  -c "model_reasoning_effort=$EFFORT"
  --ignore-user-config
  --dangerously-bypass-approvals-and-sandbox
  --json
  -o "$OUTPUT_MSG_FILE"
)
# No --ephemeral anywhere: sessions must stay on disk to be resumable later.

if [[ -n "$RESUME_ID" ]]; then
  # `codex exec resume` takes no -C; it reuses the recorded session cwd. We cd into
  # --cd (subshell) so trust/git checks behave like the fresh path. `-` = prompt on stdin.
  CODEX_ARGS=(exec resume "${CODEX_COMMON[@]}" "$RESUME_ID" -)
else
  CODEX_ARGS=(exec "${CODEX_COMMON[@]}")
  if [[ -n "$WORKDIR" ]]; then
    CODEX_ARGS+=(-C "$WORKDIR")
  fi
fi

run_pipeline() (
  if [[ -n "$RESUME_ID" && -n "$WORKDIR" ]]; then
    cd "$WORKDIR" || exit 2
  fi
  printf '%s' "$PROMPT" | codex "${CODEX_ARGS[@]}" | python3 "$LIVE_LOG_PY" --harness codex --log "$LOG_FILE"
)

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

# Prefer live-log final; fall back to -o last message if filter missed it
if [[ "$EXIT" -eq 0 && -s "$RESULT_FILE" ]]; then
  cat "$RESULT_FILE"
  if [[ -n "$(tail -c 1 "$RESULT_FILE" 2>/dev/null || true)" ]]; then
    printf '\n'
  fi
  exit 0
fi

if [[ -s "$OUTPUT_MSG_FILE" ]]; then
  echo "run.sh: live-log missed final result; using -o fallback (LOG=$LOG_FILE)" >&2
  cat "$OUTPUT_MSG_FILE"
  if [[ -n "$(tail -c 1 "$OUTPUT_MSG_FILE" 2>/dev/null || true)" ]]; then
    printf '\n'
  fi
  exit 0
fi

echo "run.sh: codex pipeline failed (exit $EXIT). LOG=$LOG_FILE" >&2
if [[ -s "$RESULT_FILE" ]]; then
  cat "$RESULT_FILE" >&2
fi
exit "${EXIT:-1}"
