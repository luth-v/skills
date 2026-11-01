# Skills

Reusable skills for Claude Code, Codex, Cursor, and OpenCode, including
cross-harness CLI runners, the `let-me-hold-your-beer` post-grill pipeline
(Beer), `/patrol`, and `/visualize-pr`.

## Install with the skills CLI

Install a single skill globally:

```bash
npx skills add luth-v/skills --skill claude -g -y
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
- `let-me-hold-your-beer`
- `patrol`
- `visualize-pr`

Each CLI harness skill is self-contained and requires its corresponding CLI to be
installed and authenticated. `let-me-hold-your-beer` (Beer) runs only inside T3
Code and expects `thermo-nuclear-code-quality-review`,
`improve-codebase-architecture`, and `code-review-matt`; it does not need the CLI
harness skills. It ends on a Visualize stage that runs `/visualize-pr` (skip it
with `VISUALIZE=off`), and `GATE=assume` never pauses at the Human gate, recording
each pre-review call as an Assumed decision for the PR's reviewer.
`/patrol` runs one defect patrol in T3 Code on a detached worktree: five Guards
(by default) follow Leads in parallel, HQ confirms or dismisses the strongest Report, and then a Night patrol
(`/patrol night`) runs Beer to a draft PR while an Inspection (the default)
reports in chat.
`/visualize-pr` commits the reviewed work, writes a visual PR body, publishes an
explainer (via `artifacts` on GitHub, a canvas-style publisher on Bitbucket), and
opens or updates the PR.
`archived/let-them-cook` (Cook) is archived and not maintained; see ADR-0005.

## Install from a local checkout

Install `/claude` from this checkout:

```bash
npx skills add . --skill claude -g -y
```

Install all skills from this checkout:

```bash
npx skills add . --all -g
```
