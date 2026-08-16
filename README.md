# Skills

Reusable skills for Claude Code, Codex, Cursor, and OpenCode, including
cross-harness CLI runners, the `let-them-cook` post-grill workflow, its
Cursor-only sibling `let-me-hold-your-beer`, and `/bruh`.

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
- `bruh`
- `wtf`

Each CLI harness skill is self-contained and requires its corresponding CLI to be
installed and authenticated. `let-them-cook` orchestrates the harness skills, so
install the full collection before using it; it additionally expects `/handoff` and
`thermo-nuclear-code-quality-review`. `let-me-hold-your-beer` is its Cursor-only
sibling; it expects those same two skills and does not need the CLI harness skills.
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
