#!/usr/bin/env bash
# Parse default model/effort from a skill SKILL.md defaults table.
#
# Table rows look like:
#   | model  | `claude-opus-4.8` |
#   | effort | `xhigh`           |
#
# Usage (from run.sh):
#   source ".../read-skill-defaults.sh"
#   MODEL="$(skill_default "$SKILL_MD" model)"
#   EFFORT="$(skill_default "$SKILL_MD" effort)"  # may be empty (cursor)

skill_default() {
  local skill_md="$1"
  local key="$2"
  if [[ ! -f "$skill_md" ]]; then
    echo "read-skill-defaults: missing $skill_md" >&2
    return 1
  fi
  # Case-insensitive key; value must be in backticks (markdown code span).
  local val
  val="$(
    sed -nE "s/^[[:space:]]*\|[[:space:]]*${key}[[:space:]]*\|[[:space:]]*\`([^\`]+)\`[[:space:]]*\|.*/\1/ip" "$skill_md" \
      | head -n 1
  )"
  printf '%s' "$val"
}
