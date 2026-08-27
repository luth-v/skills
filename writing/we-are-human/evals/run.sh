#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: run.sh [claude|opencode] [--judge] [case-id ...]" >&2
  echo "  runner defaults to claude; case-id filters evals/cases/<id>.txt" >&2
  echo "  transcripts -> evals/out/<case>.md ; with --judge also <case>.verdict" >&2
  exit 2
}

runner=claude
judge=false
ids=()
while [ $# -gt 0 ]; do
  case "$1" in
    claude|opencode) runner="$1" ;;
    --judge) judge=true ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) ids+=("$1") ;;
  esac
  shift
done

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$skill_dir/evals/fixture-companion.md"
out_dir="$skill_dir/evals/out"
mkdir -p "$out_dir"

run_agent() {
  local prompt="$1" cf="${2:-}"
  case "$runner" in
    claude) claude -p $cf "$prompt" ;;
    opencode) opencode run $cf "$prompt" ;;
  esac
}

judge_case() {
  local name="$1" expects="$2" transcript="$3"
  local prompt
  prompt=$(cat <<EOF
You are the judge for an agent-steering eval. Below is a transcript of a conversation between an evaluator and an AI agent, followed by a checklist of behaviors the agent was expected to show.

Rules: an item passes only when the transcript shows the agent itself producing the stated behavior. Intentions, restatements of the instructions, or absence of action do not count. Any failed item fails the case.

For each checklist item output one line: "PASS" or "FAIL" plus a one-line justification quoting the transcript. Then output a final line exactly "VERDICT: PASS" or "VERDICT: FAIL".

=== CHECKLIST ===
$expects

=== TRANSCRIPT ===
$transcript
EOF
)
  case "$runner" in
    claude) claude -p "$prompt" ;;
    opencode) opencode run "$prompt" ;;
  esac
}

for case_file in "$skill_dir"/evals/cases/*.txt; do
  name="$(basename "$case_file" .txt)"
  if [ "${#ids[@]}" -gt 0 ]; then
    keep=false
    for id in "${ids[@]}"; do
      [ "$name" = "$id" ] && keep=true
    done
    $keep || continue
  fi

  echo "== $name =="
  work="$(mktemp -d)"
  cp "$fixture" "$work/fixture-companion.md"
  transcript="$out_dir/$name.md"
  : > "$transcript"

  expects="$(grep '^# expect:' "$case_file" | sed 's/^# expect: //')"

  first=true
  while IFS= read -r -d $'\x01' turn || [ -n "$turn" ]; do
    turn="$(printf '%s' "$turn" | sed '/./,$!d')"
    [ -n "$turn" ] || continue
    cf=""
    if $first; then
      first=false
    else
      case "$runner" in
        claude) cf="--continue" ;;
        opencode) cf="--continue" ;;
      esac
    fi
    {
      echo "=== evaluator ==="
      printf '%s\n' "$turn"
      echo "=== agent ==="
    } >> "$transcript"
    (cd "$work" && run_agent "$turn" "$cf") >> "$transcript" 2>&1 || true
    printf '\n' >> "$transcript"
  done < <(printf '%s\n' "$(sed '/^# /d' "$case_file")" | sed 's/^---TURN---$/\x01/')

  if $judge; then
    judge_case "$name" "$expects" "$(cat "$transcript")" > "$out_dir/$name.verdict" 2>&1 || true
    echo "   verdict -> $out_dir/$name.verdict"
  fi
  rm -rf "$work"
done

echo "done: transcripts in $out_dir"
