# Hold runs on T3 Code

Supersedes ADR-0003. Hold (`/let-me-hold-your-beer`) now spawns every stage as a fresh T3 Code delegated task (`delegate_task`) instead of a Cursor `Task` subagent. ADR-0003 rejected a "parent-product Hold" because each product needs its own defaults table and spawn API; T3 is the one parent whose native spawn already reaches every provider (Claude, Codex, OpenCode, …) with per-task model and effort, so a single table and API covers the cross-provider hops that used to need Cook's `run.sh` Harnesses. Cook stays the pipeline for parents outside T3.

## Considered options

- **Keep the Cursor `Task` path beside T3** — two spawn worlds and two defaults tables (Cursor slugs do not map onto T3 provider + model + effort), the exact duplication ADR-0003 split Hold out to avoid.
- **A new third sibling** — Hold already had the right shape (fresh native stages, no Harness, no session reuse); a third pipeline would only fork it.

## Consequences

- Hold requires the `t3-code` MCP tools; elsewhere it stops and points at Cook. Plain Cursor sessions have no Hold.
- Hold's stages now match Cook's two-pass reviews (thermo + architecture, thermo + `code-review-matt`), but Hold's architecture pass writes no HTML report — the handoff is its only output.
- Defaults mirror Cook's table in `driverKind model [effort]` form and are copied, not referenced, so the siblings stay independently installable.
- Stage prompts ban T3 orchestration tools as well as nested agents, since child agents can see the `t3-code` tools.
