# Cook is archived; Beer is the only pipeline

Supersedes ADR-0004's sibling rule (Beer and Cook stay stage-for-stage copies). Cook (`/let-them-cook`) moves to `archived/let-them-cook/`, uninstalled and unmaintained. Beer (`/let-me-hold-your-beer`, formerly called Hold) is the only post-grill pipeline, and it runs only in T3 Code. Patrol follows: Guard and HQ spawn as T3 delegated tasks, and a Night patrol must be scheduled inside T3.

## Considered options

- **Keep both siblings** — every pipeline change (GATE=assume, Visualize, WORKSPACE) landed twice, for a pipeline nobody ran.
- **Delete Cook outright** — loses the Harness-spawned design and its session-reuse and helper-agent rules (ADR-0001) in case a non-T3 pipeline is needed again; `archived/` keeps them one `git mv` away.

## Consequences

- The four Harness runners stay: scripted callers (`~/Work/automation`) and humans still use `run.sh`. Nothing in this repo's pipelines spawns through them any more.
- Guard and HQ lose `run.sh --read-only`'s enforced read-only. T3 has no read-only mode, so Patrol relies on the stage clause and aborts with `idle: <role> wrote files` when a write check after each run finds changes.
- A scheduler outside T3 (systemd timers, cron calling `run.sh`) cannot run a Night patrol: Patrol idles with `idle: needs t3`.
- ADR-0001 (helper agents in cook stages) now describes archived behaviour only.
