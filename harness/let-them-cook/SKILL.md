---
name: let-them-cook
description: >-
  Post-grill pipeline: handoff → thermo pre-review → optional human gate → impl →
  thermo post-review → optional fix. After a grilled plan, or /let-them-cook.
argument-hint: "[STAGE=harness model [effort] | CACHE_TTL=1h|5m | HANDOFF=/path RESUME=stage]"
---

# Let Them Cook

Post-grill only — the plan is already grilled, so this skill never runs `/grilling`.

**The parent orchestrates:** the parent alone spawns stages, and it always spawns them
through a harness rather than driving a CLI itself. A stage agent implements, reviews,
or fixes — it never runs this skill, advances a stage, or takes the gate.

**Spawn target:** same harness *and* model as the current agent → that harness's
native subagent (Cursor `Task` / Claude Agent / Codex spawn / OpenCode agent).
Different harness or model → that CLI's `run.sh` (e.g. Cursor wanting fable → Claude
CLI `run.sh`).

## Helper agents

A stage agent may spawn helper agents for its own stage work — only when the human
opted in. Off by default: without opt-in every stage agent stays flat.

Opt-in is plain language, e.g. "fine to use helper agent". It covers every stage of
that cook unless the human narrows it to one stage ("helper for impl" →
`IMPLEMENTATION` only). The parent never grants helpers on its own.

Every stage prompt carries a nesting clause: `no nested agents` when that stage has no
helpers, or these limits verbatim when it does.

- Native subagent only (Cursor `Task` / Claude Agent / Codex spawn / OpenCode agent)
  on the stage's own harness — never another harness's `run.sh`.
- One nest only: a helper must not spawn helpers.
- No orchestration: no running this skill, no starting or advancing a stage, no human
  gate, no changing the Flow.
- May read the handoff and edit code; must not edit its `## Pipeline sessions`
  section.
- Helper sessions are ephemeral — no chain entry, never resumed.
- No helper count cap. The stage agent decides, keeping same-machine work bounded.

## Defaults (invoke lines override)

| Stage                   | Value                         |
| ----------------------- | ----------------------------- |
| `PRE_REVIEW`            | `claude claude-opus-5 medium` |
| `PRE_REVIEW_HELPER`     | `claude claude-opus-5 low`    |
| `IMPLEMENTATION`        | `codex gpt-5.6-sol high`      |
| `IMPLEMENTATION_HELPER` | `codex gpt-5.6-luna max`      |
| `POST_REVIEW`           | `claude claude-opus-5 medium` |
| `POST_REVIEW_HELPER`    | `claude claude-opus-5 low`    |
| `FIX`                   | `codex gpt-5.6-sol high`      |
| `FIX_HELPER`            | `codex gpt-5.6-luna max`      |

Shape: `harness model [effort]` — `claude`|`codex`|`cursor`|`opencode`. The handoff
comes from the parent's own `/handoff`.

A `*_HELPER` row is the model a stage's helpers run on; its harness always matches the
stage's, since helpers are native-only. Overriding a `*_HELPER` row picks the model —
it does not grant permission, which stays with the human's opt-in.

Override / resume:

```
/let-them-cook
IMPLEMENTATION=cursor grok-4.5-xhigh
HANDOFF=/path/to/handoff.md
RESUME=implementation
```

`RESUME`: `handoff`|`pre_review`|`implementation`|`post_review`|`fix`

- `post_review` — review only. The parent then spawns `FIX` if the handoff / `VERDICT`
  says `NEEDS_FIX`.
- `fix` — spawn FIX from the handoff findings; skip re-running POST_REVIEW.

## Flow

Each step below lists what "done" looks like. Move on when it holds.

1. **Handoff.** Run `/handoff` (or take `HANDOFF=`).
   Done when an absolute handoff path exists and is recorded for the rest of the cook.

2. **PRE_REVIEW.** Spawn it; stdin starts with `/thermo-nuclear-code-quality-review`.
   Prompt contract: treat the handoff as a **proposed implementation**, not code to
   write; rewrite that same handoff absorbing blockers; write no code; end stdout and
   the handoff with exactly `GATE: REVIEW` or `GATE: CONTINUE`.
   Done when the handoff is rewritten, nothing was implemented, and one of those two
   lines is present. No re-handoff or second pre-review unless the user asks.

3. **Human gate (only on `GATE: REVIEW`).** `GATE: REVIEW` → stop, summarize the
   blockers, and wait for the user's explicit go-ahead. `GATE: CONTINUE` → go straight
   to IMPLEMENTATION with no pause. The parent takes the gate PRE_REVIEW asked for and
   never invents one.
   Done when either the user has said go, or the run continued unpaused on
   `GATE: CONTINUE`.

4. **IMPLEMENTATION.** Spawn it. Freeform prompt, and it must say: you are the
   implementer — edit code yourself; no nested agents (or the helper limits when this
   stage has helpers); do not re-run this skill; scope is the handoff only; an open
   question means stop and report it. Pass `--cd` for codex/cursor/opencode.
   Done when the implementer reports finished work within handoff scope, with any open
   question surfaced or an explicit "none".

5. **POST_REVIEW.** Spawn once; stdin starts with `/thermo-…`. Review the
   implementation against the handoff, append findings to the handoff, no fixing, and
   no nesting (or the helper limits when this stage has helpers). End stdout **and** the
   handoff with the exact line `VERDICT: CLEAN` or `VERDICT: NEEDS_FIX`.
   Thermo approval bar: must-fix or structural blockers →
   `NEEDS_FIX`; nits and suggestions → still `CLEAN`, listed as optional.
   Done when findings are on the handoff and exactly one verdict line appears in both
   places.

6. **FIX (only on `NEEDS_FIX`).** Spawn once (defaults or `FIX=`). Prompt: fix the
   findings in the handoff post-review section; handoff-only scope; no re-review; no
   nesting (or the helper limits when this stage has helpers); append the fix outcome
   and any leftovers to the handoff. Leftovers are an acceptable outcome, not a stage
   failure. `CLEAN` → skip this step.
   Done when the taken branch is complete: FIX ran and appended its outcome, or the
   verdict was `CLEAN`.

7. **Report.** Tell the user the handoff path and the outcome. No commit, no PR.
   Done when the user has the path and the result in hand.

**Session-reuse gate — every spawn in steps 2/4/5/6.** Before spawning, scan the
handoff's `## Pipeline sessions` bottom-up for an earlier `status: ok` entry matching
this stage's harness + model + effort. Match → announce `resuming <harness> session
<id> for <STAGE>` and spawn with `--resume <id>` plus the hybrid resume prompt. No
match → announce `fresh spawn <harness> <model> <effort> for <STAGE>`. After the
stage, capture `SESSION=` and append a chain entry. Full rules — chain format, hybrid
prompt, resume miss — in `session-reuse.md` (installed:
`$HOME/.agents/skills/let-them-cook/session-reuse.md`).

A stage failure stops the cook: note it on the handoff and report. No retry.

## Prompt-cache TTL (Claude only)

Claude spawns default to `--cache-ttl 1h` via `claude/SKILL.md`, so the parent passes
nothing for the default case. The human may set one whole-cook override:

```
/let-them-cook
CACHE_TTL=5m
HANDOFF=/path/to/handoff.md
```

Valid values are `1h` and `5m`; anything else → stop and ask. This is an invoke-line
key, not a shell variable. The parent translates an override into `--cache-ttl
"$CACHE_TTL"` on **every** Claude spawn in that cook, resumed stages included — one
TTL per cook.

`5m` suits a known-short cook: 1h cache writes bill at 2x base input versus 1.25x for
5m, while reads are 0.1x either way, and only a strict harness + model + effort match
collects the read benefit. A human override wins.

Cursor, Codex, and OpenCode expose no prompt-cache TTL control; session reuse still
applies to all of them, with no keepalive runs between stages.

## Cross-harness CLI and live progress

Run scripts, flags, `--cd` requirements, the `SESSION=` line, `LOG=` live-log lookup,
and `/skill-name` chaining all follow
`_shared/parent-harness-contract.md` beside this `SKILL.md` (repo source:
`harness/_shared/parent-harness-contract.md`). Read it before the first spawn and
follow it as written.

Cook-specific notes on top of that contract:

- Wait for each stage synchronously (high `block_until_ms`). On a user nudge or long
  silence mid-stage, read the stage's `LOG=` file before assuming it is stuck.
- A chained skill missing from the target harness's skills dir → stop and tell the
  user.
- Same-harness **native** subagents (Cursor `Task`, Claude Agent, …): use that
  surface's own resume/agent id if it exposes one; if it does not, spawn fresh and
  record no chain entry.
