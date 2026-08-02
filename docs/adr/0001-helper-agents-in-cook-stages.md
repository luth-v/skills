# Helper agents in cook stages

`/let-them-cook` used to allow exactly one level of orchestration: the parent spawned
stages and every stage prompt said "no nested agents". Stage agents doing real work
(implementation especially) want to fan out, so a cook stage agent may now spawn
**helper agents** for its own stage — but only when the human opts in with plain
language ("fine to use helper agent"), which covers the whole cook unless narrowed to
one stage ("helper for impl"). Flat stays the default so no cook silently grows a tree.

## Considered options

- **Always flat** (status quo) — simplest and cheapest, but forces the stage agent to
  do explore/build/verify work serially in one context.
- **Cross-harness helpers via `run.sh`** — the spawn square already supports it, but it
  multiplies unsandboxed CLI processes on one machine for a case we do not have yet. A
  later defaults row can open it.
- **An invoke-line flag** (`HELPERS=on`) — machine-readable, but not how the human
  actually asks; the chat phrasing would drift from the flag.
- **Deeper nesting** — a helper spawning helpers gains little when a stage agent can
  spawn peers instead, and it compounds process, timeout, and session bookkeeping.

## Consequences

- Helpers are **native subagents only** on the stage's own harness, **one nest deep**,
  and may not orchestrate (no stage, no gate, no re-running the skill).
- Helper sessions are **ephemeral** — outside the `## Pipeline sessions` chain, so
  session reuse still keys on stages alone and helpers cannot be cold-resumed.
- Each stage has a `*_HELPER` defaults row, so helper model choice is explicit rather
  than inherited. `FIX` moved to `codex gpt-5.6-sol high` with `gpt-5.6-luna max`
  running its helpers.
- There is no helper count cap. Bounding same-machine fan-out is the stage agent's
  judgment, which the skill can advise but not enforce.
