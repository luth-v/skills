# Harness Skills (luth-v)

Cross-harness agent install kit: CLI runners, the post-grill Cook pipeline, and its Cursor-only sibling Hold.

## Language

**Harness**:
One of the four CLI runner skills — `claude`, `codex`, `cursor`, `opencode` — that spawn that product's CLI as a blocking subagent via `run.sh`.
_Avoid_: runner, wrapper, delegate skill, subagent skill

**Cook**:
The `let-them-cook` pipeline — post-grill orchestration across stages (handoff → pre-review → gate → impl → post-review → optional fix), spawning each stage through a Harness.
_Avoid_: pipeline skill, let-them-cook (as a concept name; keep as the slash name)

**Hold**:
The sibling pipeline to Cook — same stages, Cursor-only. The parent spawns each stage as a fresh native subagent with that stage's model; never a Harness, never a helper agent, never session reuse. Slash name `/let-me-hold-your-beer`.
_Avoid_: simple cook, in-place cook, local cook, same-harness cook, hold-my-beer, let-me-hold-your-beer (as a concept name; keep as the slash name)

**Parent–harness contract**:
Shared rules for how any parent (including cook) talks to a harness: `run.sh` paths and flags, live-log lookup, and skill-chaining stdin shape. Lives at `_shared/parent-harness-contract.md`; not the cook stage flow.
_Avoid_: shared helpers, common docs, runner API

**Session reuse**:
Cold resume of an earlier stage's exact session id within one cook, keyed by harness + model + effort. Detail lives in `let-them-cook/session-reuse.md`; the cook Flow only keeps the check/announce/spawn gate.
_Avoid_: keepalive, warm session, continue, --last

**Human gate**:
Optional pause after PRE_REVIEW before IMPLEMENTATION, in a Cook or a Hold. Taken only when PRE_REVIEW ends handoff and stdout with `GATE: REVIEW`; `GATE: CONTINUE` means proceed with no pause. Parent never invents a gate. Not a `RESUME=` value — after a `REVIEW` stop, the human continues the same Cook or Hold in chat.
_Avoid_: always-wait, mandatory approval, RESUME=gate

**Helper agent**:
A nested spawn created by a cook stage agent to help finish that stage's work — not a cook stage and not parent orchestration. Opt-in is human language (e.g. "fine to use helper agent"); that permission covers the whole cook unless the human narrows it (e.g. "helper for impl"). Without opt-in, stage agents stay flat (no nesting).
_Avoid_: nested pipeline, sub-stage, subagent skill, grandchild harness
