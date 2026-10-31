# Skills

Reusable skills for Claude Code, Codex, Cursor, and OpenCode, including
cross-harness CLI runners, the `let-them-cook` post-grill workflow, its
T3 Code sibling `let-me-hold-your-beer`, `/patrol`, `/visualize-pr`, and `/bruh`.

## Install with the skills CLI

Install a single skill globally:

```bash
npx skills add luth-v/skills --skill bruh -g -y
```

Install all skills globally:

```bash
npx skills add luth-v/skills --all -g
```

Available skills:

- `claude`
- `codex`
- `cursor`
- `opencode`
- `let-them-cook`
- `let-me-hold-your-beer`
- `patrol`
- `visualize-pr`
- `bruh`
- `wtf`

Each CLI harness skill is self-contained and requires its corresponding CLI to be
installed and authenticated. `let-them-cook` orchestrates the harness skills, so
install the full collection before using it; it additionally expects
`thermo-nuclear-code-quality-review`. `let-me-hold-your-beer` is its T3 Code
sibling; it runs only inside T3 Code, expects that skill plus
`improve-codebase-architecture` and `code-review-matt`, and does not need the CLI
harness skills. Both end on a Visualize stage that runs `/visualize-pr` (skip it
with `VISUALIZE=off`), and both accept `GATE=assume`, which never pauses at the
Human gate and records each pre-review call as an Assumed decision for the PR's
reviewer.
`/patrol` runs one defect patrol on a detached worktree: a Guard follows Leads,
HQ confirms or dismisses one Report, and then a Night patrol (`/patrol night`)
runs the pipeline to a draft PR while an Inspection (the default) reports in chat.
`/visualize-pr` commits the reviewed work, writes a visual PR body, publishes an
explainer (via `artifacts` on GitHub, a canvas-style publisher on Bitbucket), and
opens or updates the PR.
`/bruh` is a standalone plain-language restatement skill.

## Install from a local checkout

Install `/bruh` from this checkout:

```bash
npx skills add . --skill bruh -g -y
```

Install all skills from this checkout:

```bash
npx skills add . --all -g
```
