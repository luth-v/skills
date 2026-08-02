---
name: codex
description: >-
  Spawn Codex CLI (`codex exec`) as blocking subagent. Use when the user wants a
  harness to delegate to Codex CLI, or says /codex. Chain another skill by putting
  `/skill-name` first in the stdin prompt.
argument-hint: "[model]"
---

# Codex

## Default Model and Effort

**SoT = this table.** Change here when models ship. Agent passes `--model` / `--effort` from this table (or user override) into `scripts/run.sh`. If flags/env omitted, `run.sh` parses this file.

| Key    | Value         |
| ------ | ------------- |
| model  | `gpt-5.6-sol` |
| effort | `high`        |

Subagent runs use `--ignore-user-config`, so `~/.codex/config.toml` never changes
these values — pass a flag or env override instead.

## Req

- `codex` on PATH
- Trusted project dir (pass `--cd`)
- Auth ok (`codex login`)

## Invoke deltas

Skill arg = **model override only** (optional). No task arg. Agent composes the prompt
from chat.

```bash
RUN="$HOME/.agents/skills/codex/scripts/run.sh"
printf '%s' "SELF-CONTAINED PROMPT HERE" | "$RUN" --cd /path/to/workspace
```

Shared flags (`--model`, `--effort`, `--resume`, `--timeout` / `--no-timeout`) work as
described in the parent–harness contract. Env equivalents: `CODEX_SUBAGENT_MODEL`,
`CODEX_SUBAGENT_EFFORT`, `CODEX_SUBAGENT_TIMEOUT`.

`--cd` is required for every run. `--resume` takes the exact thread id from a prior
run's `SESSION=` line.

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
3. Wait for exit. Done when stdout holds the last agent message; non-zero exit means
   failure — read `LOG=` for the reason.
4. Summarize for the user. Done when the outcome is stated in prose.

## Script behavior (fixed)

- model/effort from SKILL.md table (or `--model` / `--effort` / `CODEX_SUBAGENT_*`)
  via `-m` / `-c model_reasoning_effort=...`
- `--ignore-user-config` (no `config.toml` for subagent runs; auth still uses
  `CODEX_HOME`)
- `--dangerously-bypass-approvals-and-sandbox` (non-interactive)
- `--json` streamed via `_shared/live-log.py`; `-o` kept as final-message fallback
- optional `--resume <thread_id>` → `codex exec resume <id>` (exact id; no `--ephemeral`)
- stdin required; `--cd` required
- timeout off by default (`0`); optional via `--timeout` / `CODEX_SUBAGENT_TIMEOUT`

## Limits

- Same-machine Codex-in-Codex: keep tasks bounded
- Parent MCP servers are not shared — only what Codex itself has
- Long interactive work → interactive `codex`, not `codex exec`
