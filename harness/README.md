# Harness skills (luth-v)

Agent install kit: cross-harness runners (`claude` / `codex` / `cursor` / `opencode`), shared live-log helpers, and `/let-them-cook`.

## Agent install

Peer prompt example:

> help install this skills: https://github.com/luth-v/skills

Do this exactly:

1. Clone (skip if already present — any local path is fine):

```bash
git clone https://github.com/luth-v/skills.git
```

2. Run install from that checkout (idempotent; migrates links from the former
   `harnesses/` path and never overwrites unrelated targets):

```bash
./skills/harness/install.sh
```

`install.sh` derives the kit path from its own location. There is no fixed clone directory.

3. Verify:

```bash
ls -la ~/.agents/skills/{_shared,claude,codex,cursor,opencode,let-them-cook}
ls -la ~/.claude/skills/{claude,codex,cursor,opencode,let-them-cook}
ls -la ~/.codex/skills/{claude,codex,cursor,opencode,let-them-cook}
ls -la ~/.cursor/skills/{claude,codex,cursor,opencode,let-them-cook}
```

### What install does

| Step | Action |
|------|--------|
| SoT | Symlink kit → `~/.agents/skills/{_shared,claude,codex,cursor,opencode,let-them-cook}` |
| Slash | Symlink the 5 skills → `~/.claude/skills`, `~/.codex/skills`, `~/.cursor/skills` |
| Migrate | Symlinks into this repo's former `harnesses/` path → point at `harness/` |
| Skip | Unrelated existing file, directory, or symlink → skip |
| Thermo | If `thermo-nuclear-code-quality-review` missing → `npx skills add https://github.com/cursor/plugins --skill thermo-nuclear-code-quality-review` |

Each published CLI harness includes its own generated `_shared/` runtime, so installing
one of `claude`, `codex`, `cursor`, or `opencode` through `npx skills add` is sufficient.
`let-them-cook` orchestrates those harnesses and should be installed with the full
collection. The top-level `_shared` link remains for backward compatibility with older
checkouts.

### skills.sh install

Install one harness globally:

```bash
npx skills add luth-v/skills --skill claude -g -y
```

Install all five:

```bash
npx skills add luth-v/skills --all -g
```

### Prerequisites (not installed here)

- **`/handoff`** — required before `/let-them-cook` (bring your own)
- **CLI auth** — `claude`, `codex`, `cursor`, and/or `opencode` on PATH as needed

### Update

From the same checkout you installed from:

```bash
git -C /path/to/skills pull
/path/to/skills/harness/install.sh
```

Links from this repository's former `harnesses/` path are migrated automatically.
Unrelated links and real directories are left alone. To re-point those at this checkout,
remove them under `~/.agents/skills` and the harness slash dirs, then re-run install.

## Layout

```
harness/
  README.md          ← this file
  install.sh
  sync-shared.sh     regenerate each skill's self-contained `_shared/` runtime
  _shared/           live-log filter for CLI runners
    parent-harness-contract.md   run.sh paths/flags, SESSION=, LOG=, /skill-name chaining
  claude/            /claude skill + scripts/run.sh
  codex/             /codex skill + scripts/run.sh
  cursor/            /cursor skill + scripts/run.sh
  opencode/          /opencode skill + scripts/run.sh
  let-them-cook/     /let-them-cook pipeline skill
    session-reuse.md             cold-resume rules for cook stages
```

Every harness `SKILL.md` points at `_shared/parent-harness-contract.md` for the rules
shared by all parents; each keeps only its own flags, script behavior, and limits.

After changing `harness/_shared/`, run:

```bash
./harness/sync-shared.sh
```

Commit the generated per-skill `_shared/` copies with the source change.

## Model defaults (single SoT)

Defaults live **only** in each skill’s `SKILL.md` table (same idea as `/let-them-cook` stage defaults).

| CLI | `--model` | `--effort` | Default file |
|-----|-----------|------------|--------------|
| claude | yes | yes | `claude/SKILL.md` |
| codex | yes | yes | `codex/SKILL.md` |
| cursor | yes | no (effort in model slug) | `cursor/SKILL.md` |
| opencode | yes | yes | `opencode/SKILL.md` |

Agent should pass `--model` / `--effort` from that table or from user override. If omitted, `scripts/run.sh` parses the sibling `SKILL.md`. Do **not** hardcode defaults in `run.sh`.

`/let-them-cook` stage overrides, e.g.:

```
/let-them-cook
IMPLEMENTATION=cursor grok-4.5-xhigh
HANDOFF=/path/to/handoff.md
```
