# Parent–harness contract

Shared rules for how any parent agent (including `/let-them-cook` and `/hunter`) talks to a harness
CLI runner. Reference doc, not a skill — nothing here loads on its own.

Installed path: `<skill>/_shared/parent-harness-contract.md`
Repo source: `harness/_shared/parent-harness-contract.md`

Each harness `SKILL.md` keeps only its own deltas (unique flags, script behavior,
limits) and points here for everything below.

## Run scripts

| harness    | script                                         | `--cd` |
| ---------- | ---------------------------------------------- | ------ |
| `claude`   | `$HOME/.agents/skills/claude/scripts/run.sh`   | no     |
| `codex`    | `$HOME/.agents/skills/codex/scripts/run.sh`    | yes    |
| `cursor`   | `$HOME/.agents/skills/cursor/scripts/run.sh`   | yes    |
| `opencode` | `$HOME/.agents/skills/opencode/scripts/run.sh` | yes    |

Shape:

```bash
printf '%s' "$PROMPT" | "$RUN" [--cd "$WORKSPACE"] --model "$MODEL" [--effort "$EFFORT"] [--resume "$SESSION_ID"]
```

Common flags, all four runners:

| Flag                | Meaning                                                             |
| ------------------- | ------------------------------------------------------------------- |
| `--model <id>`      | Model override; default comes from that harness's SKILL.md table     |
| `--effort <level>`  | Reasoning effort where the CLI exposes one (cursor: effort in slug)  |
| `--resume <id>`     | Cold resume of an **exact** session id from a prior `SESSION=` line  |
| `--timeout <secs>`  | Optional wall cap                                                    |
| `--no-timeout`      | Default behaviour — wait until the CLI finishes                      |

Pass `--cd` with the workspace root (or a tighter scope the user named) for codex,
cursor, and opencode. Claude Code resolves its own working directory, so `claude`
takes no `--cd`.

Stdin is required — every runner reads the prompt from the pipe. Give the subagent a
self-contained prompt: it sees no parent chat, so paste the paths, diff summary, and
handoff text it needs.

When you set `--timeout`, give the shell a `block_until_ms` of at least timeout + 30s.
With no timeout, use a high `block_until_ms` (the outer shell may still kill the job).

## Session id

Each runner prints one machine-readable line on stderr once the id is known:

```
SESSION=<id>
```

Parents capture it with `grep '^SESSION='` (on the stderr stream or the log file) and
resume later with `--resume <that exact id>`. Use exact ids only — `--last`,
`--continue`, bare `--resume`, and "most recent on this machine" all pick the wrong
conversation.

## Live progress log

Every runner streams progress while the parent blocks. Synchronous waiting is fine.

- Early stderr line: `LOG=<abs path>` under `$TMPDIR/agent-subagent/`
- Stable symlink: `$TMPDIR/agent-subagent/latest-<harness>.log`
- Human lines (tool calls, short assistant crumbs) go to stderr **and** that log
- Stdout carries the final result text only
- Logs are kept after exit

Note the `LOG=` path when you spawn. On a user nudge or a long silence, `Read` or
`tail` that log (or `latest-<harness>.log`) to see where the run is. That answers
"is it stuck?" without burning a second full run.

## Chaining a skill into the subagent

When the parent wants the subagent to run another skill (e.g. `spawn /codex for
thermo-nuclear-code-quality-review`), let the target harness load that skill itself.

1. Resolve the name to its slash form: `/skill-name`, kebab-case, no `@`, no path.
2. Put that slash command on the **first line of stdin**, then a blank line, then the
   task (repo path, scope, diff hints, output shape).
3. Let `/skill-name` supply the rubric. Paste the skill's contents only when the user
   explicitly asks for it.
4. Confirm the skill exists in the target harness's skill dir when unsure. If it is
   missing, tell the user and let them decide — a generic prompt silently does
   different work.

```bash
printf '%s' "/thermo-nuclear-code-quality-review

Review uncommitted changes in /Users/me/Repo/app.
Focus on internal/enrollment/. Return findings per the skill output expectations." \
  | "$RUN" --cd /Users/me/Repo/app
```

Skill dirs by harness: claude `~/.claude/skills/`, codex `~/.codex/skills/`,
cursor `~/.cursor/skills/`, opencode `~/.agents/skills/` (symlinks OK everywhere).

User phrasing → stdin prefix:

| User says                                                    | Stdin prefix                          |
| ------------------------------------------------------------ | ------------------------------------- |
| `for thermo-nuclear` / `@thermo-nuclear-code-quality-review` | `/thermo-nuclear-code-quality-review` |
| `with /grilling`                                             | `/grilling`                           |
| `using handoff skill`                                        | `/handoff`                            |

`@skill` attachments in the parent's UI are not forwarded to any CLI. The slash line
in the piped prompt is what loads the skill.

## Spawn square

Any harness can delegate to any other — same table, same contract. Pick the target's
`run.sh`, pipe a self-contained prompt (or `/skill-name` + task for a skill in that
harness's skill dir), add `--cd` where the table says yes. Always go through `run.sh`
rather than a native task tool when the target is a different harness or model.
