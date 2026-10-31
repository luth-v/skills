# Harness Skills (luth-v)

Agent install kit: CLI runners, the post-grill Beer pipeline, and Patrol.

## Language

**Harness**:
One of the four CLI runner skills — `claude`, `codex`, `cursor`, `opencode` — that spawn that product's CLI as a blocking subagent via `run.sh`. Used by scripted callers and by hand; no pipeline in this repo spawns through one.
_Avoid_: runner, wrapper, delegate skill, subagent skill

**Beer**:
The post-grill pipeline (handoff → pre-review → gate → impl → post-review → optional fix → Visualize), T3 Code only. The parent spawns each stage as a fresh T3 delegated task on that stage's provider and model. Slash name `/let-me-hold-your-beer`.
_Avoid_: Hold, hold-my-beer, let-me-hold-your-beer (as a concept name; keep as the slash name), cook

**Cook**:
The archived `let-them-cook` pipeline, which spawned each stage through a Harness. Kept under `archived/`, not installed or maintained; Beer replaces it.
_Avoid_: using it as a live pipeline name

**Patrol**:
A single run that roams a repo looking for defects, follows Leads, and escalates to HQ. Runs as a Night patrol or an Inspection, T3 Code only. Scheduling is the caller's job, not the Patrol's. Slash name `/patrol`. Replaces Hunter.
_Avoid_: hunter, scan, audit, sweep, loop

**Night patrol**:
The unattended Patrol mode, run on a schedule. Defects only; a confirmed Report runs a Beer that ends in a draft PR, never a merge. Must be asked for by name.
_Avoid_: light patrol, scheduled mode, auto mode

**Inspection**:
The attended Patrol mode, run by a human and the default. Also weighs architecture and product changes; a confirmed Report goes back to the human for grilling and never starts a pipeline on its own.
_Avoid_: dedicated patrol, manual mode, deep patrol

**Guard**:
One of the agents in a Patrol (five by default, in parallel) that roams the code from its own random start file, follows Leads, and decides which one is worth a Report.
_Avoid_: hunter, scout, scanner

**Lead**:
Something suspicious the Guard is still checking. Most Leads are dropped; none leave the Patrol.
_Avoid_: candidate, finding, take

**Report**:
A Lead a Guard has checked enough to escalate to HQ. HQ gets every Guard's Report and investigates the strongest. It carries a scenario, the rule it breaks, and the cited code.
_Avoid_: take, ticket, finding

**HQ**:
The stronger agent that investigates a Report in depth and confirms or dismisses it. Only a confirmed Report leaves the Patrol.
_Avoid_: warden, consultant, confirmer, reviewer

**Visualize**:
The last stage of a Beer: opens or updates the PR with its visual explainer through `/visualize-pr`. On by default.
_Avoid_: create-pr stage, PR stage, publish stage

**Parent–harness contract**:
Shared rules for how any parent talks to a Harness: `run.sh` paths and flags, live-log lookup, and skill-chaining stdin shape. Lives at `_shared/parent-harness-contract.md`.
_Avoid_: shared helpers, common docs, runner API

**Human gate**:
Pause after PRE_REVIEW before IMPLEMENTATION, in a Beer. The default `GATE=auto` pauses only when PRE_REVIEW ends handoff and stdout with `GATE: REVIEW`; `GATE: CONTINUE` proceeds with no pause. `GATE=assume` never pauses: on `GATE: REVIEW` it accepts every pre-review recommendation and records each as an **Assumed decision** for the PR's reviewer. Parent never invents a gate beyond its mode. Not a `RESUME=` value — after a stop, the human continues the same Beer in chat.
_Avoid_: mandatory approval, RESUME=gate
