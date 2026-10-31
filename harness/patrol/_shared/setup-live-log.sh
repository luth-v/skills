#!/usr/bin/env bash
# Source from run.sh: source "$SHARED_DIR/setup-live-log.sh" <harness>
# Sets: LIVE_LOG_PY, LOG_DIR, LOG_FILE
# Prints LOG=... to stderr and creates latest-<harness>.log symlink.

set -euo pipefail

_HARNESS="${1:-}"
if [[ -z "$_HARNESS" ]]; then
  echo "setup-live-log.sh: harness required" >&2
  return 2 2>/dev/null || exit 2
fi

_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_LOG_PY="${LIVE_LOG_PY:-$_SHARED_DIR/live-log.py}"
if [[ ! -f "$LIVE_LOG_PY" ]]; then
  echo "setup-live-log.sh: missing $LIVE_LOG_PY" >&2
  return 127 2>/dev/null || exit 127
fi

LOG_DIR="${TMPDIR:-/tmp}/agent-subagent"
mkdir -p "$LOG_DIR"
_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/${_HARNESS}-$$-${_UTC}.log"
{
  echo "LOG=$LOG_FILE"
  echo "harness=${_HARNESS} runner_pid=$$"
} >"$LOG_FILE"
ln -sfn "$LOG_FILE" "$LOG_DIR/latest-${_HARNESS}.log"
# Parent nudge lookup: path on stderr immediately (before CLI starts)
echo "LOG=$LOG_FILE" >&2
