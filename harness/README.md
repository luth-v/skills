# Harness skills (luth-v)

Agent install kit: cross-harness runners (`claude` / `codex` / `cursor` /
`opencode`), shared live-log helpers, Cook (`/let-them-cook`), its
Cursor-native sibling Hold (`/let-me-hold-your-beer`), and Hunter (`/hunter`).

## Install the skills

Use the standard skills CLI to install this repository's skills:

```bash
npx skills add luth-v/skills --all -g
```

Install one harness skill:

```bash
npx skills add luth-v/skills --skill claude -g -y
```

Install `/bruh`:

```bash
npx skills add luth-v/skills --skill bruh -g -y
```

`/bruh` is a standalone skill. `let-them-cook` orchestrates the harness skills and
additionally expects `/handoff` and `thermo-nuclear-code-quality-review`.
`let-me-hold-your-beer` runs the same pipeline with fresh Cursor native subagents;
it expects those same skills and does not need the CLI harness skills.
`/hunter` files at most one GitHub take ticket per invoke and expects the CLI
harness skills (it spawns Warden through `run.sh`).

### skills.sh install

Install one harness globally:

```bash
npx skills add luth-v/skills --skill claude -g -y
```

Install all skills:

```bash
npx skills add luth-v/skills --all -g
```

### Prerequisites (not installed here)

- **`/handoff`** — required by Cook and by Hold when no `HANDOFF=` is supplied
- **`/thermo-nuclear-code-quality-review`** — required by Cook and Hold
- **CLI auth** — `claude`, `codex`, `cursor`, and/or `opencode2` on PATH as needed

### Update

Update installed skills with the standard CLI:

```bash
npx skills update -g
```

For a local checkout, pull the repository and reinstall the selected skill:

```bash
git -C /path/to/skills pull
npx skills add /path/to/skills --skill claude -g -y
```

## Layout

```
misc/
  bruh/             /bruh plain-language restatement skill
harness/
  README.md          ← this file
  sync-shared.sh     regenerate each skill's self-contained `_shared/` runtime
  _shared/           live-log filter for CLI runners
    parent-harness-contract.md   run.sh paths/flags, SESSION=, LOG=, /skill-name chaining
  claude/            /claude skill + scripts/run.sh
  codex/             /codex skill + scripts/run.sh
  cursor/            /cursor skill + scripts/run.sh
  opencode/          /opencode skill + scripts/run.sh
  let-them-cook/     /let-them-cook pipeline skill
    session-reuse.md             cold-resume rules for cook stages
  let-me-hold-your-beer/         /let-me-hold-your-beer Cursor-native pipeline
    SKILL.md                      self-contained; no _shared/ runtime
  hunter/            /hunter one-tick defect hunter (Warden via a Harness)
```

Every harness `SKILL.md` points at `_shared/parent-harness-contract.md` for the rules
shared by all parents; each keeps only its own flags, script behavior, and limits.

After changing `harness/_shared/`, run:

```bash
./harness/sync-shared.sh
```

Commit the generated per-skill `_shared/` copies with the source change.

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
