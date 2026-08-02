# Harness skills

Cross-harness CLI runners for Claude Code, Codex, Cursor, and OpenCode, plus the
`let-them-cook` post-grill workflow.

## Install with the skills CLI

Install a single harness globally:

```bash
npx skills add luth-v/skills --skill claude -g -y
```

Install all harness skills globally:

```bash
npx skills add luth-v/skills --all -g
```

Available skills:

- `claude`
- `codex`
- `cursor`
- `opencode`
- `let-them-cook`

Each CLI harness skill is self-contained and requires its corresponding CLI to be
installed and authenticated. `let-them-cook` orchestrates the harness skills, so
install the full collection before using it; it additionally expects `/handoff` and
`thermo-nuclear-code-quality-review`.

## Install from a checkout

For a symlinked development installation that updates with the checkout:

```bash
git clone https://github.com/luth-v/skills.git
./skills/harness/install.sh
```

See [harness/README.md](harness/README.md) for the layout, migration behavior, and
maintenance workflow.
