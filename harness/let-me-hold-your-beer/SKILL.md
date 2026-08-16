---
name: let-me-hold-your-beer
description: >-
  Post-grill pipeline run entirely in Cursor: handoff → thermo pre-review →
  optional human gate → impl → thermo post-review → optional fix. After a
  grilled plan when the parent is Cursor, or /let-me-hold-your-beer.
argument-hint: "[STAGE=model | HANDOFF=/path RESUME=stage]"
---

# Let Me Hold Your Beer

Hold is Cook's Cursor-only sibling. The plan is already grilled, so Hold never
runs `/grilling`; it starts from a handoff and runs every stage as a fresh
Cursor native subagent.

**The parent orchestrates:** the parent alone spawns stages and never implements.
A stage agent implements, reviews, or fixes. It never runs this skill, advances a
stage, or takes the Human gate. Every stage prompt carries `no nested agents`.

Hold requires a Cursor parent. In another product, stop and tell the user to use
Cook. Before starting, confirm `/thermo-nuclear-code-quality-review` is in the
Cursor skills list. Confirm `/handoff` too unless the invocation supplies
`HANDOFF=`. Stop and report a missing required skill.

## Defaults (invoke lines override)

| Stage            | Model                             |
| ---------------- | --------------------------------- |
| `PRE_REVIEW`     | `claude-fable-5-thinking-xhigh`    |
| `IMPLEMENTATION` | `gpt-5.6-sol-medium`               |
| `POST_REVIEW`    | `claude-fable-5-thinking-xhigh`    |
| `FIX`            | `gpt-5.6-sol-medium`               |

An override has the shape `STAGE=model` and accepts one model slug:

```
/let-me-hold-your-beer
IMPLEMENTATION=gpt-5.6-luna-max
HANDOFF=/path/to/handoff.md
RESUME=implementation
```

`RESUME`: `handoff`|`pre_review`|`implementation`|`post_review`|`fix`

- `post_review` — run POST_REVIEW, then FIX if its verdict is `NEEDS_FIX`.
- `fix` — run FIX from the handoff findings, without re-running POST_REVIEW.

For every stage, announce `fresh spawn cursor <model> for <STAGE>`, then create a
fresh Task subagent and pass that stage's model slug. Task is the model
enforcement point. If Task rejects the slug, stop and report it.

## Flow

Each step below lists what "done" looks like. Move on when it holds.

1. **Handoff.** Run the parent's own `/handoff`, or take `HANDOFF=`.
   Done when an absolute handoff path exists and is recorded for the rest of the
   Hold.

2. **PRE_REVIEW.** Spawn it with a prompt starting
   `/thermo-nuclear-code-quality-review`. Tell it to treat the handoff as a
   **proposed implementation**, not code to write; rewrite that same handoff to
   absorb blockers; write no code; and end stdout **and** the handoff with exactly
   `GATE: REVIEW` or `GATE: CONTINUE`.
   Done when the handoff is rewritten, nothing was implemented, and the same one
   of those two lines appears in both places. Run no re-handoff or second
   pre-review unless the user asks.

3. **Human gate (only on `GATE: REVIEW`).** On `GATE: REVIEW`, stop, summarize the
   blockers, and wait for the user's explicit go-ahead. On `GATE: CONTINUE`, go
   straight to IMPLEMENTATION. The parent takes only the gate PRE_REVIEW asked
   for.
   Done when the user has said go, or the run continued unpaused on
   `GATE: CONTINUE`.

4. **IMPLEMENTATION.** Spawn it. The prompt must say: you are the implementer;
   edit code yourself; do not run this skill; scope is the handoff only; an open
   question means stop and report it.
   Done when the implementer reports finished work within handoff scope, with
   every open question surfaced or an explicit "none".

5. **POST_REVIEW.** Spawn it once with a prompt starting
   `/thermo-nuclear-code-quality-review`. Tell it to review the implementation
   against the handoff, append findings to the handoff, and make no fixes. It
   ends stdout **and** the handoff with exactly `VERDICT: CLEAN` or
   `VERDICT: NEEDS_FIX`. Must-fix or structural blockers mean `NEEDS_FIX`; nits
   and suggestions remain `CLEAN` and are listed as optional.
   Done when findings are appended and the same one of those verdict lines
   appears in both places.

6. **FIX (only on `NEEDS_FIX`).** Spawn it once. Tell it to fix the findings in
   the handoff's post-review section, stay within handoff scope, skip re-review,
   and append the fix outcome and any leftovers to the handoff. Leftovers are an
   acceptable outcome. On `CLEAN`, skip this step.
   Done when FIX ran and appended its outcome, or POST_REVIEW returned `CLEAN`.

7. **Report.** Tell the user the handoff path and outcome. Create no commit or
   pull request.
   Done when the user has the path and result in hand.

A stage failure stops the Hold: note the failure on the handoff and report it
without retrying.
