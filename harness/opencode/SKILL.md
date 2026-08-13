---
name: opencode
description: >-
  Spawn OpenCode 2 CLI (`opencode2 run`) as blocking subagent. Use when the user wants a
  harness to delegate to OpenCode CLI, or says /opencode. Chain another skill by
  putting `/skill-name` first in the stdin prompt.
---

# OpenCode

## Default Model and Effort

**SoT = this table.** Change here when models ship. Agent passes `--model` / `--effort` from this table (or user override) into `scripts/run.sh`. If flags/env omitted, `run.sh` parses this file.

| Key    | Value                 |
| ------ | --------------------- |
| model  | `opencode-go/kimi-k3` |
| effort | `max`                 |

## Req

- `opencode2` on PATH
- Trusted project dir (pass `--cd`)
- Auth configured for the selected provider/model

## Invoke deltas

Skill arg = **model override only** (optional). No task arg. Agent composes the prompt
from chat.

```bash
RUN="$HOME/.agents/skills/opencode/scripts/run.sh"
printf '%s' "SELF-CONTAINED PROMPT HERE" | "$RUN" --cd /path/to/workspace
```

Shared flags (`--model`, `--effort`, `--resume`, `--timeout` / `--no-timeout`) work as
described in the parent–harness contract. Env equivalents: `OPENCODE_SUBAGENT_MODEL`,
`OPENCODE_SUBAGENT_EFFORT`, `OPENCODE_SUBAGENT_TIMEOUT`.

`--cd` is required for every run and maps to the `opencode2 run` process's working
directory. Models are `provider/model` slugs; `--effort` maps to the model reference's
`#variant` suffix, so `--model` must not include a variant. OpenCode loads skills from
`~/.agents/skills/` — the same tree this kit installs into.

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
3. Wait for exit. Done when stdout holds the completed assistant text; non-zero exit
   means failure — read `LOG=` for the reason.
4. Summarize for the user. Done when the outcome is stated in prose, no raw JSON dump
   unless asked.

## Script behavior (fixed)

- model/effort from SKILL.md table (or `--model` / `--effort` / `OPENCODE_SUBAGENT_*`)
  combined as `-m provider/model#variant`
- `opencode2 run -m …#… --auto --format json --standalone`, with `--cd` applied as a
  process working-directory change
- `--auto` for non-interactive permissions; no `--pure`
- JSONL filtered via `_shared/live-log.py` with harness `opencode`
- optional `--resume <session_id>` → `opencode2 run -s <id>` (exact id)
- stdin required; `--cd` required and mapped to the process working directory
- timeout off by default (`0`); optional via `--timeout` / `OPENCODE_SUBAGENT_TIMEOUT`

## Limits

- Same-machine OpenCode-in-OpenCode: keep tasks bounded
- Tool/MCP availability depends on OpenCode configuration
- No prompt-cache TTL control
- Long interactive work → interactive `opencode2`, not `opencode2 run`
