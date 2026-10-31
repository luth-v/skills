# Harness Skills (luth-v)

Cross-harness agent install kit: CLI runners, the post-grill Cook pipeline, its T3 Code sibling Hold, and Patrol.

## Language

**Harness**:
One of the four CLI runner skills — `claude`, `codex`, `cursor`, `opencode` — that spawn that product's CLI as a blocking subagent via `run.sh`.
_Avoid_: runner, wrapper, delegate skill, subagent skill

**Cook**:
The `let-them-cook` pipeline — post-grill orchestration across stages (handoff → pre-review → gate → impl → post-review → optional fix), spawning each stage through a Harness.
_Avoid_: pipeline skill, let-them-cook (as a concept name; keep as the slash name)

**Hold**:
The sibling pipeline to Cook — same stages, T3 Code only. The parent spawns each stage as a fresh T3 delegated task on that stage's provider and model; never a Harness, never a helper agent, never session reuse. Slash name `/let-me-hold-your-beer`.
_Avoid_: simple cook, in-place cook, local cook, same-harness cook, hold-my-beer, let-me-hold-your-beer (as a concept name; keep as the slash name)

**Patrol**:
A single run that roams a repo looking for defects, follows Leads, and escalates to HQ. Runs as a Night patrol or an Inspection. Scheduling is the caller's job, not the Patrol's. Slash name `/patrol`. Replaces Hunter.
_Avoid_: hunter, scan, audit, sweep, loop

**Night patrol**:
The unattended Patrol mode, run by a cron or automation. Defects only; a confirmed Report runs a Hold (or Cook) that ends in a draft PR, never a merge. Must be asked for by name.
_Avoid_: light patrol, scheduled mode, auto mode

**Inspection**:
The attended Patrol mode, run by a human and the default. Also weighs architecture and product changes; a confirmed Report goes back to the human for grilling and never starts a pipeline on its own.
_Avoid_: dedicated patrol, manual mode, deep patrol

**Guard**:
The agent in a Patrol that roams the code, follows Leads, and decides which one is worth a Report.
_Avoid_: hunter, scout, scanner

**Lead**:
Something suspicious the Guard is still checking. Most Leads are dropped; none leave the Patrol.
_Avoid_: candidate, finding, take

**Report**:
A Lead the Guard has checked enough to escalate to HQ. It carries a scenario, the rule it breaks, and the cited code.
_Avoid_: take, ticket, finding

**HQ**:
The stronger agent that investigates a Report in depth and confirms or dismisses it. Only a confirmed Report leaves the Patrol.
_Avoid_: warden, consultant, confirmer, reviewer

**Visualize**:
The last stage of a Cook or Hold: opens or updates the PR with its visual explainer through `/visualize-pr`. On by default.
_Avoid_: create-pr stage, PR stage, publish stage

**Parent–harness contract**:
Shared rules for how any parent (including Cook and Patrol) talks to a harness: `run.sh` paths and flags, live-log lookup, and skill-chaining stdin shape. Lives at `_shared/parent-harness-contract.md`; not the cook stage flow.
_Avoid_: shared helpers, common docs, runner API

**Session reuse**:
Cold resume of an earlier stage's exact session id within one cook, keyed by harness + model + effort. Detail lives in `let-them-cook/session-reuse.md`; the cook Flow only keeps the check/announce/spawn gate.
_Avoid_: keepalive, warm session, continue, --last

**Human gate**:
Pause after PRE_REVIEW before IMPLEMENTATION, in a Cook or a Hold. Cook's `GATE=always` (default) pauses after every PRE_REVIEW; Cook's `GATE=auto` and Hold's default `GATE=auto` pause only when PRE_REVIEW ends handoff and stdout with `GATE: REVIEW`, and `GATE: CONTINUE` proceeds with no pause. `GATE=assume` (Cook or Hold) never pauses: on `GATE: REVIEW` it accepts every pre-review recommendation and records each as an **Assumed decision** for the PR's reviewer. Parent never invents a gate beyond its mode. Not a `RESUME=` value — after a stop, the human continues the same Cook or Hold in chat.
_Avoid_: mandatory approval, RESUME=gate

**Helper agent**:
A nested spawn created by a cook stage agent to help finish that stage's work — not a cook stage and not parent orchestration. Opt-in is human language (e.g. "fine to use helper agent"); that permission covers the whole cook unless the human narrows it (e.g. "helper for impl"). Without opt-in, stage agents stay flat (no nesting).
_Avoid_: nested pipeline, sub-stage, subagent skill, grandchild harness
