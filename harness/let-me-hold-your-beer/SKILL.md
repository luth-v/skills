---
name: let-me-hold-your-beer
description: >-
  Post-grill pipeline run on T3 Code delegated tasks: handoff → thermo +
  architecture pre-review → optional human gate → impl → thermo +
  code-review-matt post-review → optional fix → visual PR. After a grilled plan
  when the parent runs in T3 Code, or /let-me-hold-your-beer.
argument-hint: "[STAGE=driverKind model [effort] | VISUALIZE=off | GATE=auto|assume | DRAFT=yes | WORKSPACE=/abs/path | HANDOFF=/path RESUME=stage]"
---

# Let Me Hold Your Beer

Beer is the post-grill pipeline. The plan is already grilled, so Beer never
runs `/grilling`; it starts from a handoff and runs every stage as a fresh T3
delegated task (`delegate_task`), on any provider T3 offers.

**The parent orchestrates:** the parent alone spawns stages and never implements.
A stage agent implements, reviews, fixes, or visualizes. It never runs this skill, advances a
stage, or takes the Human gate. Every stage prompt carries the **stage clause**:
`no nested agents and no T3 orchestration tools (delegate_task, task_*,
t3_thread_*, create_threads, schedule_task)`.

Beer requires T3 Code. Without the `t3-code` tools (`orchestrator_capabilities`,
`delegate_task`), stop and tell the user to run it from a T3 Code thread.

## Defaults (invoke lines override)

| Stage            | Value                                                 |
| ---------------- | ----------------------------------------------------- |
| `PRE_REVIEW`     | `claudeAgent claude-opus-5-5 xhigh`                   |
| `IMPLEMENTATION` | `claudeAgent claude-opus-5-5 medium`                  |
| `POST_REVIEW`    | `claudeAgent claude-opus-5-5 xhigh`                   |
| `FIX`            | `claudeAgent claude-opus-5-5 medium`                  |
| `VISUALIZE`      | `claudeAgent claude-opus-5-5 xhigh`, or `off` to skip |

Shape: `driverKind model [effort]`, where
`driverKind` is a T3 provider driver (`claudeAgent`, `codex`, `opencode`, …).

```
/let-me-hold-your-beer
IMPLEMENTATION=codex gpt-6.1-sol high
HANDOFF=/path/to/handoff.md
RESUME=implementation
```

`RESUME`: `handoff`|`pre_review`|`implementation`|`post_review`|`fix`|`visualize`

- `post_review` — run POST_REVIEW, then FIX if its verdict is `NEEDS_FIX`.
- `fix` — run FIX from the handoff findings, without re-running POST_REVIEW.
- `visualize` — run VISUALIZE only.

Run keys:

- `GATE=auto|assume` — the Human gate mode. `auto` (default) or `assume`;
  anything else → stop and ask.
- `DRAFT=yes` — Visualize opens the PR as a draft.
- `WORKSPACE=/abs/path` — the checkout the whole Beer works in. Default: the
  repo root of the parent's cwd.

## Spawning a stage

1. **Resolve the instance.** Call `orchestrator_capabilities` once per Beer. For
   the stage's `driverKind`: the parent's own instance when its driver matches,
   else the only instance with that driver, else stop and ask which one.
2. **Map effort** onto the model's advertised effort option (`effort` on Claude,
   `reasoningEffort` on Codex, `variant` on OpenCode). A model with no effort
   option runs without one.
3. **Announce** `fresh spawn <instance> <model> <effort> for <STAGE>`, or
   `… (no effort control) …` when step 2 dropped it.
4. **Spawn** with `delegate_task`, `mode: async`, a fresh `clientRequestId` per
   stage, and the stage prompt. Then end the turn: T3 wakes the parent on
   completion, and the Flow resumes from that notification. Call `task_status`
   only when the user nudges mid-stage.

T3 is the model enforcement point: a rejected provider, model, or option is a
stage failure, not a fallback.

Every stage prompt names its skills with this **loading rule**: load `/<skill>`
with your skill tool; if it is not available, read
`~/.agents/skills/<skill>/SKILL.md` and follow it; if that is missing too, stop
and report.

## Flow

Each step below lists what "done" looks like. Move on when it holds.

1. **Handoff.** Take `HANDOFF=`, or write the handoff yourself from this
   conversation: one markdown file in the OS temp directory (`$TMPDIR`, else
   `/tmp`) that a fresh agent can implement from. Reference existing artifacts
   (specs, plans, ADRs, `CONTEXT.md`, issues, diffs) by path instead of copying
   them, redact secrets and personal data, and end with a `## Suggested skills`
   section. `/handoff` is user-only (`disable-model-invocation`), so the parent
   writes this file itself rather than calling it.
   Record `WORKSPACE: <abs path>` in the handoff, from `WORKSPACE=` or else the
   repo root of the parent's cwd. From then on every parent git command runs as
   `git -C "$WORKSPACE"`, and every stage prompt says "work only inside the
   handoff's `WORKSPACE:`". T3 delegated tasks get WORKSPACE through the prompt
   only.
   Done when the absolute handoff path and its `WORKSPACE:` line exist.

2. **PRE_REVIEW.** One stage agent runs two passes in order. Shared contract:
   treat the handoff as a **proposed implementation**, not code to write; rewrite
   that same handoff absorbing blockers; write no code.
   - Pass A: `/thermo-nuclear-code-quality-review` of the proposal. No gate line.
   - Pass B: `/improve-codebase-architecture` in pipeline mode. Scope the scan to
     the modules the handoff touches (skip the git-log hot-spot hunt), and
     explore inline. Write no HTML report and skip the grilling loop. Deepening
     the proposal needs to stay sound → absorb into the handoff. Every other
     candidate → one short entry under `### Deferred architecture candidates` in
     the handoff, not implemented. Leave `CONTEXT.md` and ADRs untouched.
   - Both passes: each absorbed change that needs a human call becomes one entry
     under `### Assumed decisions`: what was assumed, the alternative, and why.
     A handoff `## Scope`, when present, outranks absorbing: a deepening outside
     it goes to `### Deferred architecture candidates`.
   - Pass B ends stdout **and** the handoff with exactly `GATE: REVIEW` or
     `GATE: CONTINUE`, covering both passes: `REVIEW` when either pass raised a
     blocker or `### Assumed decisions` is non-empty.
   Done when the handoff is rewritten by both passes, nothing was implemented,
   and the same gate line appears in both places. Run no re-handoff or second
   pre-review unless the user asks.

3. **Human gate.** Mode comes from `GATE=`.
   - `auto`: on `GATE: REVIEW`, stop, summarize `### Assumed decisions`, the
     blockers, and the deferred architecture candidates from the handoff, and
     wait for the user's explicit go-ahead. Apply the edits the user asks for to
     the handoff and remove the Assumed decisions entries the user settled,
     before IMPLEMENTATION. On `GATE: CONTINUE`, go straight to IMPLEMENTATION.
   - `assume`: never pause. Go straight to IMPLEMENTATION and leave
     `### Assumed decisions` in place for Visualize.
   Done when the user has said go, or the run continued unpaused on
   `GATE: CONTINUE` or under `assume`.

4. **IMPLEMENTATION.** Before spawning, if the handoff has no `BASE:` line,
   record `BASE: $(git -C "$WORKSPACE" rev-parse HEAD)` in it (plus
   `BASE_DIRTY: yes` when WORKSPACE already had changes). Then spawn. The
   prompt must say: you are the implementer; edit code yourself; the stage clause; do not run this skill;
   scope is the handoff only; an open question means stop and report it.
   Done when the implementer reports finished work within handoff scope, with
   every open question surfaced or an explicit "none".

5. **POST_REVIEW.** One fresh stage agent runs two passes in order. Shared
   contract: review the implementation against the handoff, append findings to
   the handoff, make no fixes.
   - Pass A: `/thermo-nuclear-code-quality-review`; findings under `### Thermo`.
     No verdict line.
   - Pass B: `/code-review-matt` in pipeline mode. The fixed point is the
     handoff's `BASE:`; the diff, run in WORKSPACE, is `git diff <BASE>`
     (working tree) plus untracked files from `git status --porcelain`. The spec is the handoff
     itself — skip issue-tracker lookup and never ask the user. Run the Standards
     and Spec axes one after the other inline, appended as `### Standards` and
     `### Spec`, not merged or reranked. `BASE:` missing → stop and report.
   - Pass B ends stdout **and** the handoff with exactly `VERDICT: CLEAN` or
     `VERDICT: NEEDS_FIX`, covering all three sections.
   Approval bar: thermo must-fix or structural blockers, a hard
   documented-standard violation, or a Spec finding (missing, partial, or wrong
   requirement) → `NEEDS_FIX`. Nits, baseline smells, and scope-creep notes
   alone → still `CLEAN`, listed as optional.
   Done when all three sections are on the handoff and the same verdict line
   appears in both places.

6. **FIX (only on `NEEDS_FIX`).** Spawn it once. Tell it to fix the must-fix
   findings in the handoff's post-review sections, stay within handoff scope,
   skip re-review, follow the stage clause, and append the fix outcome to the
   handoff, with any leftovers under a `### Leftovers` heading. Leftovers are
   an acceptable outcome. On `CLEAN`, skip this step.
   Done when FIX ran and appended its outcome, or POST_REVIEW returned `CLEAN`.

7. **VISUALIZE (skipped when `VISUALIZE=off`).** First, when the handoff has
   `BASE_DIRTY: yes` and no `BASE_DIRTY_DECISION:` line: under `auto`, ask the
   user how to handle the earlier changes and record the answer as
   `BASE_DIRTY_DECISION: <answer>` in the handoff; under `assume`, stop with the
   stage failure `workspace dirty`. Then spawn it once, fresh. The
   prompt: run `/visualize-pr HANDOFF=<path>` (plus `--draft` when `DRAFT=yes`)
   inside the handoff's `WORKSPACE:`, follow the stage clause, and end stdout on
   `PR: <url>`. `/visualize-pr` owns commit, branch, push, and the PR body.
   Done when the stage's last line is `PR: <url>`, or `VISUALIZE=off` skipped
   the step.

8. **Report.** Tell the user the handoff path and outcome, plus the PR URL when
   Visualize ran, and link the PR with the PR-linking tool when one is
   available. With `VISUALIZE=off`, nothing is committed and no PR is opened.
   Done when the user has the path, the result, and the PR URL when Visualize
   ran.

A stage failure stops the Beer: note the failure on the handoff and report it
without retrying.
