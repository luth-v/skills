# Harness skills (luth-v)

Agent install kit: cross-harness runners (`claude` / `codex` / `cursor` / `opencode`), shared live-log helpers, and `/let-them-cook`.

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

### skills.sh install

Install one harness globally:

```bash
npx skills add luth-v/skills --skill claude -g -y
```

Install all six skills:

```bash
npx skills add luth-v/skills --all -g
```

### Prerequisites (not installed here)

- **`/handoff`** — required before `/let-them-cook` (bring your own)
- **CLI auth** — `claude`, `codex`, `cursor`, and/or `opencode` on PATH as needed

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
