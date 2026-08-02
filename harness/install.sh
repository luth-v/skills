#!/usr/bin/env bash
# Install luth-v harness skills into the local agent skill tree.
# Idempotent: migrate links from this repo's old harnesses/ path; otherwise
# never overwrite an existing target.
#
# Run from any checkout of this repo:
#   /path/to/skills/harness/install.sh
#
# Kit layout (this directory):
#   harness/{install.sh,_shared,claude,codex,cursor,opencode,let-them-cook}
set -euo pipefail

AGENTS_ROOT="${AGENTS_ROOT:-$HOME/.agents/skills}"

SKILLS=(claude codex cursor opencode let-them-cook)
SHARED=(_shared)

HARNESS_SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.cursor/skills"
)

THERMO_SKILL=thermo-nuclear-code-quality-review

log() { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }

abs_dir() {
  (cd "$1" && pwd -P)
}

link_safe() {
  local src="$1"
  local dest="$2"
  local current

  if [[ -L "$dest" ]]; then
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      log "skip (current): $dest"
      return 0
    fi
    if [[ "$current" == "$OLD_HARNESS_DIR" || "$current" == "$OLD_HARNESS_DIR/"* ]]; then
      rm "$dest"
      ln -s "$src" "$dest"
      log "migrated: $dest -> $src"
      return 0
    fi
    log "skip (unrelated symlink): $dest -> $current"
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    log "skip (exists): $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log "linked: $dest -> $src"
}

thermo_present() {
  local d
  for d in "${HARNESS_SKILL_DIRS[@]}" "$AGENTS_ROOT"; do
    if [[ -e "$d/$THERMO_SKILL" || -L "$d/$THERMO_SKILL" ]]; then
      return 0
    fi
  done
  return 1
}

HARNESS_DIR="$(abs_dir "$(dirname "${BASH_SOURCE[0]}")")"
REPO_ROOT="$(abs_dir "$HARNESS_DIR/..")"
OLD_HARNESS_DIR="$REPO_ROOT/harnesses"

for name in "${SHARED[@]}" "${SKILLS[@]}"; do
  if [[ ! -d "$HARNESS_DIR/$name" ]]; then
    warn "missing $HARNESS_DIR/$name"
    warn "run this script from a complete harness/ checkout of the skills repo"
    warn "example: git clone https://github.com/luth-v/skills.git && ./skills/harness/install.sh"
    exit 1
  fi
done

log "kit: $HARNESS_DIR"
mkdir -p "$AGENTS_ROOT"

# 1) Flatten into ~/.agents/skills.
for name in "${SHARED[@]}" "${SKILLS[@]}"; do
  link_safe "$HARNESS_DIR/$name" "$AGENTS_ROOT/$name"
done

# 2) Slash skills into every harness skills dir (not _shared)
for dest_root in "${HARNESS_SKILL_DIRS[@]}"; do
  for name in "${SKILLS[@]}"; do
    link_safe "$HARNESS_DIR/$name" "$dest_root/$name"
  done
done

# 3) Thermo from upstream if missing
if thermo_present; then
  log "skip (exists): $THERMO_SKILL"
else
  log "installing $THERMO_SKILL via npx skills add"
  if command -v npx >/dev/null 2>&1; then
    if ! npx skills add https://github.com/cursor/plugins --skill "$THERMO_SKILL"; then
      warn "thermo install failed — install manually:"
      warn "  npx skills add https://github.com/cursor/plugins --skill $THERMO_SKILL"
    fi
  else
    warn "npx not found — install manually:"
    warn "  npx skills add https://github.com/cursor/plugins --skill $THERMO_SKILL"
  fi
  if ! thermo_present; then
    warn "$THERMO_SKILL still not found; /let-them-cook pre/post review needs it"
  fi
fi

log ""
log "done."
log "prerequisite: /handoff must already exist (not installed by this script)."
log "update later:"
log "  git -C $REPO_ROOT pull"
log "  $HARNESS_DIR/install.sh"
log "re-point an existing install at this checkout:"
log "  remove unrelated targets under $AGENTS_ROOT (and harness slash dirs), then re-run"
