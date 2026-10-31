# Harness skills (luth-v)

Agent install kit: cross-harness runners (`claude` / `codex` / `cursor` /
`opencode`), shared live-log helpers, Beer (`/let-me-hold-your-beer`), and
Patrol (`/patrol`). Cook (`/let-them-cook`) is archived under `archived/`.

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

`/bruh` is a standalone skill. `let-me-hold-your-beer` (Beer) runs the post-grill
pipeline as fresh T3 Code delegated tasks and does not need the CLI harness skills.
It ends on a Visualize stage that runs `/visualize-pr` (in `engineering/`) to
commit the reviewed work and open a visual PR; `VISUALIZE=off` skips it.
`GATE=assume` never pauses at the Human gate and leaves each pre-review call in the
handoff as an Assumed decision for the PR's reviewer.
`/patrol` runs one defect patrol per invoke, in T3 Code only: its Guards
(`GUARDS=`, default 5; `LEADS=` per Guard, default 15) and HQ spawn as T3 delegated tasks, and a Night patrol then runs Beer with
`GATE=assume DRAFT=yes`.

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

- **`/thermo-nuclear-code-quality-review`** — required by Beer
- **`/visualize-pr`** — Visualize stage of Beer (this repo, `engineering/`)
- **`/improve-codebase-architecture`**, **`/code-review-matt`** — required by Beer
- **T3 Code** — Beer and Patrol run only as T3 Code threads (need the `t3-code` MCP tools)
- **CLI auth** — `claude`, `codex`, `agent`/`cursor-agent`, and/or `opencode2` on PATH as needed

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
  let-me-hold-your-beer/         /let-me-hold-your-beer (Beer) T3 Code pipeline
    SKILL.md                      self-contained; no _shared/ runtime
  patrol/            /patrol defect patrol (T3 Code; Guard and HQ as delegated tasks)
archived/
  let-them-cook/     Cook, archived (ADR-0005); not installed or maintained
engineering/
  visualize-pr/      /visualize-pr commit + visual PR body + explainer
```

Every harness `SKILL.md` points at `_shared/parent-harness-contract.md` for the rules
shared by all parents; each keeps only its own flags, script behavior, and limits.

After changing `harness/_shared/`, run:

```bash
./harness/sync-shared.sh
```

Commit the generated per-skill `_shared/` copies with the source change.

Defaults live **only** in each skill’s `SKILL.md` table.

| CLI | `--model` | `--effort` | Default file |
|-----|-----------|------------|--------------|
| claude | yes | yes | `claude/SKILL.md` |
| codex | yes | yes | `codex/SKILL.md` |
| cursor | yes | no (effort in model slug) | `cursor/SKILL.md` |
| opencode | yes | yes | `opencode/SKILL.md` |

Agent should pass `--model` / `--effort` from that table or from user override. If omitted, `scripts/run.sh` parses the sibling `SKILL.md`. Do **not** hardcode defaults in `run.sh`.
