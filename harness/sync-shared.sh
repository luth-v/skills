#!/usr/bin/env bash
# Copy the canonical shared harness runtime into every published skill package.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS=(claude codex cursor opencode let-them-cook)

for name in "${SKILLS[@]}"; do
  dest="$HARNESS_DIR/$name/_shared"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$HARNESS_DIR/_shared/." "$dest/"
done

printf 'synced shared runtime into: %s\n' "${SKILLS[*]}"
