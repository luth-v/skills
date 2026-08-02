---
name: cursor
description: >-
  Spawn Cursor Agent CLI (`cursor agent -p`) as blocking subagent. Use when the user
  wants a harness to delegate to Cursor CLI, or says /cursor. Chain another skill by
  putting `/skill-name` first in the stdin prompt.
argument-hint: "[model]"
---

# Cursor

## Default Model

**SoT = this table.** Change here when models ship. Agent passes `--model` from this table (or user override) into `scripts/run.sh`. If flag/env omitted, `run.sh` parses this file.

| Key   | Value            |
| ----- | ---------------- |
| model | `grok-4.5-xhigh` |

Subagent runs do not inherit the user's IDE model pick from `cli-config.json`.
Reasoning effort rides in the model slug — there is no separate `--effort` flag.

## Req

- `cursor` on PATH
- Trusted project dir (pass `--cd`)
- Auth ok (`cursor agent login` or `CURSOR_API_KEY`)

## Invoke deltas

Skill arg = **model override only** (optional). No task arg. Agent composes the prompt
from chat.

```bash
RUN="$HOME/.agents/skills/cursor/scripts/run.sh"
printf '%s' "SELF-CONTAINED PROMPT HERE" | "$RUN" --cd /path/to/workspace
```

Shared flags (`--model`, `--resume`, `--timeout` / `--no-timeout`) work as described in
the parent–harness contract. Env equivalents: `CURSOR_SUBAGENT_MODEL`,
`CURSOR_SUBAGENT_TIMEOUT`.

`--cd` is required for every run. Pick effort by choosing a model slug, e.g.
`--model grok-4.5-xhigh`.

## Agent steps

Before spawning or chaining, read `_shared/parent-harness-contract.md` beside this
`SKILL.md` (repo source: `harness/_shared/parent-harness-contract.md`). Follow it for run.sh
invocation, live-log nudge, and `/skill-name` chaining. Do not restate those rules
inline.

1. Build stdin per the contract — `/skill-name` + blank line + task when a skill is
   chained, otherwise a self-contained prompt (goal, constraints, output shape).
   Done when stdin carries every path and context the subagent needs.
2. Pipe it to `run.sh` with `--cd` set to the workspace root (or the tighter scope the
   user named) and note the `LOG=` line from stderr. Done when the run is launched and
   the log path is recorded.
3. Wait for exit. Done when stdout holds the final result text; non-zero exit means
   failure — read `LOG=` for the reason.
4. Summarize for the user. Done when the outcome is stated in prose, no raw JSON dump
   unless asked.

Reach Cursor through this `run.sh`, including from inside Cursor — the Cursor Task
tool is a different surface and does not honour this contract.

## Script behavior (fixed)

- model from SKILL.md table (or `--model` / `CURSOR_SUBAGENT_MODEL`; not IDE pick)
- `--trust --force --approve-mcps` (non-interactive)
- `--output-format stream-json` (filtered via `_shared/live-log.py`)
- optional `--resume <session_id>` → `cursor agent -p --resume <id>` (exact id)
- stdin required (no bare `cursor agent -p` — hang risk)
- timeout off by default (`0`); optional via `--timeout` / `CURSOR_SUBAGENT_TIMEOUT`

## Limits

- Same-machine Cursor-in-Cursor: keep tasks bounded
- Parent MCP servers are not shared — only what Cursor Agent CLI has
- Long interactive work → interactive `cursor agent`, not `-p`
