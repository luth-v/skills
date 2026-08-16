# Hold is a Cursor-only sibling of Cook

Cook stays the cross-Harness pipeline. Hold (`/let-me-hold-your-beer`) runs the same stages as fresh Cursor native subagents with a per-stage model table — never `run.sh`, helpers, or session reuse — so the simple path cannot grow Harness machinery, and Cook remains for Claude↔Codex hops.

## Considered options

- **Mode or rewrite of Cook** — one skill, two spawn worlds; the simple path would keep inheriting contract, reuse, and helper text.
- **All stages on the Cursor CLI Harness** — one Harness column, still `run.sh` and the parent–harness contract.
- **Parent-product Hold** — portable native spawn, but a defaults table and spawn API per product.

## Consequences

- The skill lives at `harness/let-me-hold-your-beer/` next to Cook so both pipelines are found together, even though Hold never uses a Harness.
- Task is the enforcement point for legal model slugs; `cursor agent --list-models` is a browsing aid, not the runtime allowlist. The parent still spawns via Task, not `run.sh`; a Task reject is a stop, not a CLI fallback.
