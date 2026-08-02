---
name: claude
description: >-
  Spawn Claude Code CLI (`claude -p`) as blocking subagent. Use when the user wants
  a harness to delegate to Claude CLI, or says /claude. Chain another skill by
  putting `/skill-name` first in the stdin prompt.
argument-hint: "[model]"
---

# Claude

## Default Model, Effort, and Cache TTL

**SoT = this table.** Change here when models ship. Agent passes `--model` / `--effort` / `--cache-ttl` from this table (or user override) into `scripts/run.sh`. If flags/env omitted, `run.sh` parses this file.

| Key       | Value           |
| --------- | --------------- |
| model     | `claude-opus-5` |
| effort    | `medium`        |
| cache_ttl | `1h`            |

## Req

- `claude` on PATH
- Trusted project dir
- Auth ok (`claude auth`)
- No `--cd` — Claude Code resolves its own working directory

## Invoke deltas

Skill arg = **model override only** (optional). No task arg. Agent composes the prompt
from chat.

```bash
RUN="$HOME/.agents/skills/claude/scripts/run.sh"
printf '%s' "SELF-CONTAINED PROMPT HERE" | "$RUN"
```

Shared flags (`--model`, `--effort`, `--resume`, `--timeout` / `--no-timeout`) work as
described in the parent–harness contract. Env equivalents:
`CLAUDE_SUBAGENT_MODEL`, `CLAUDE_SUBAGENT_EFFORT`, `CLAUDE_SUBAGENT_TIMEOUT`.

Unique to this harness — prompt-cache TTL, default `1h`:

```bash
printf '%s' "PROMPT" | "$RUN" --cache-ttl 5m
```

`CLAUDE_SUBAGENT_CACHE_TTL=5m` is the equivalent env override. Valid values are `1h`
and `5m`. The runner explicitly sets the selected cache env var and clears the other,
so inherited parent state cannot override the choice.

The plain `ENABLE_PROMPT_CACHING_1H` setting does not cover the Bedrock provider;
Bedrock cache-TTL control is outside this skill's scope.

## Agent steps

Before spawning or chaining, read `_shared/parent-harness-contract.md` beside this
`SKILL.md` (repo source: `harness/_shared/parent-harness-contract.md`). Follow it for run.sh
invocation, live-log nudge, and `/skill-name` chaining. Do not restate those rules
inline.

1. Build stdin per the contract — `/skill-name` + blank line + task when a skill is
   chained, otherwise a self-contained prompt (goal, constraints, output shape).
   Done when stdin carries every path and context the subagent needs.
2. Pipe it to `run.sh` with the flags above and note the `LOG=` line from stderr.
   Done when the run is launched and the log path is recorded.
3. Wait for exit. Done when stdout holds the final result text; non-zero exit means
   failure — read `LOG=` for the reason.
4. Summarize for the user. Done when the outcome is stated in prose, no raw JSON dump
   unless asked.

## Script behavior (fixed)

- model/effort/cache TTL from SKILL.md table (or flags / `CLAUDE_SUBAGENT_*`)
- `--tools default`
- `--permission-mode bypassPermissions` (no interactive approve in `-p`)
- `--output-format stream-json --verbose` (filtered via `_shared/live-log.py`)
- optional `--resume <session_id>` → `claude -p --resume <id>` (exact id; sessions persist)
- stdin required (no bare `claude -p` — hang risk)
- timeout off by default (`0`); optional via `--timeout` / `CLAUDE_SUBAGENT_TIMEOUT`

## Limits

- Same-machine Claude-in-Claude: keep tasks bounded
- Parent MCP servers are not shared — only what Claude Code itself has
- Long interactive work → interactive `claude`, not `-p`
