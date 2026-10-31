---
name: let-them-cook
description: >-
  Post-grill pipeline: handoff → thermo + architecture pre-review → human gate →
  impl → thermo + code-review-matt post-review → optional fix → visual PR. After
  a grilled plan, or /let-them-cook.
argument-hint: "[STAGE=harness model [effort] | VISUALIZE=off | GATE=always|auto|assume | DRAFT=yes | WORKSPACE=/abs/path | CACHE_TTL=1h|5m | HANDOFF=/path RESUME=stage]"
---

# Let Them Cook

Post-grill only — the plan is already grilled, so this skill never runs `/grilling`.

**The parent orchestrates:** the parent alone spawns stages, and it always spawns them
through a harness rather than driving a CLI itself. A stage agent implements, reviews,
or fixes — it never runs this skill, advances a stage, or takes the gate.

**Spawn target:** stage harness same as the parent's (the agent the human is talking
to) → that harness's native subagent (Cursor `Task` / Claude Agent / Codex spawn /
OpenCode agent), whatever the stage's model and effort. Set the model through the
native surface's model option, and the effort through an agent definition that carries
it when the harness has one (Claude: `effort:` in `.claude/agents/*.md` frontmatter —
`cook-xhigh` exists for xhigh stages; same effort as the parent → default agent).
No way to set it → the stage inherits the parent's effort; say so in the spawn
announcement rather than letting it pass silently. Different harness → that CLI's
`run.sh` (e.g. Cursor wanting fable → Claude CLI `run.sh`).

**Native stages are never reused.** Every native stage spawn is fresh: no resume, no
continuing an earlier agent by id (e.g. Claude `SendMessage`), no chain entry. Session
reuse applies only to `run.sh` spawns.

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

| Stage                   | Value                                            |
| ----------------------- | ------------------------------------------------ |
| `PRE_REVIEW`            | `claude claude-opus-5-5 xhigh`                   |
| `PRE_REVIEW_HELPER`     | `claude claude-opus-5-5 medium`                  |
| `IMPLEMENTATION`        | `claude claude-opus-5-5 medium`                  |
| `IMPLEMENTATION_HELPER` | `claude claude-opus-5-5 medium`                  |
| `POST_REVIEW`           | `claude claude-opus-5-5 xhigh`                   |
| `POST_REVIEW_HELPER`    | `claude claude-opus-5-5 medium`                  |
| `FIX`                   | `claude claude-opus-5-5 medium`                  |
| `FIX_HELPER`            | `claude claude-opus-5-5 medium`                  |
| `VISUALIZE`             | `claude claude-opus-5-5 xhigh`, or `off` to skip |
| `VISUALIZE_HELPER`      | `claude claude-opus-5-5 medium`                  |

Shape: `harness model [effort]` — `claude`|`codex`|`cursor`|`opencode`.

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

`RESUME`: `handoff`|`pre_review`|`implementation`|`post_review`|`fix`|`visualize`

- `post_review` — review only. The parent then spawns `FIX` if the handoff / `VERDICT`
  says `NEEDS_FIX`.
- `fix` — spawn FIX from the handoff findings; skip re-running POST_REVIEW.
- `visualize` — spawn VISUALIZE only.

Run keys: `GATE=` (see **Human gate**), `DRAFT=yes` (Visualize opens the PR as a
draft), and `WORKSPACE=/abs/path` (the checkout the whole cook works in; default: the
repo root of the parent's cwd).

## Flow

Each step below lists what "done" looks like. Move on when it holds.

1. **Handoff.** Take `HANDOFF=`, or write the handoff yourself from this
   conversation: one markdown file in the OS temp directory (`$TMPDIR`, else
   `/tmp`) that a fresh agent can implement from. Reference existing artifacts
   (specs, plans, ADRs, `CONTEXT.md`, issues, diffs) by path instead of copying
   them, redact secrets and personal data, and end with a `## Suggested skills`
   section. `/handoff` is user-only (`disable-model-invocation`), so the parent
   writes this file itself rather than calling it.
   Record `WORKSPACE: <abs path>` in the handoff, from `WORKSPACE=` or else the repo
   root of the parent's cwd. From then on:
   - every parent git command runs as `git -C "$WORKSPACE"`;
   - every stage prompt says "work only inside the handoff's `WORKSPACE:`";
   - every `run.sh` spawn, at every stage, takes `--cd "$WORKSPACE"` for codex,
     cursor, and opencode, and runs from `cd "$WORKSPACE" && …` for claude (see the
     contract);
   - native spawns get WORKSPACE through the prompt only.
   Done when the absolute handoff path and its `WORKSPACE:` line exist.

2. **PRE_REVIEW.** Two passes in one stage, same triple: pass A runs
   `/thermo-nuclear-code-quality-review`, pass B `/improve-codebase-architecture`.
   - `run.sh` spawn: pass A is a spawn (subject to the session-reuse gate) whose stdin
     starts with pass A's slash line. Pass B resumes pass A's session with stdin
     starting with pass B's slash line — a new slash line is the only way the second
     skill loads.
   - Native spawn: one fresh agent runs both passes in order. The prompt tells it to
     load each skill with its skill tool, or to read that skill's `SKILL.md` when the
     skill is not model-invocable (`/improve-codebase-architecture` has
     `disable-model-invocation: true`).
   Shared contract: treat the handoff as a **proposed implementation**, not code to
   write; rewrite that same handoff absorbing blockers; write no code.
   - Pass A: thermo review of the proposal. No gate line.
   - Pass B, pipeline mode: scope the scan to the modules the handoff touches (the
     handoff is the named direction — skip the git-log hot-spot hunt). Explore inline
     unless this stage has helpers. Write the HTML report and record its absolute
     path in the handoff, but do not open it, do not ask which candidate to explore,
     and skip the grilling loop entirely. Deepening the proposal needs to stay sound
     → absorb into the handoff. Everything else → a `### Deferred architecture
     candidates` list in the handoff, not implemented. Do not edit `CONTEXT.md` or
     ADRs.
   - Both passes: write each absorbed change that needs a human call as one entry
     under `### Assumed decisions`: what was assumed, the alternative, and why. A
     handoff `## Scope`, when present, outranks absorbing: a deepening outside it
     goes to `### Deferred architecture candidates`.
   - Pass B ends stdout and the handoff with exactly `GATE: REVIEW` or
     `GATE: CONTINUE`, covering both passes: `REVIEW` when either pass raised a
     blocker or `### Assumed decisions` is non-empty.
   Done when the handoff is rewritten by both passes, nothing was implemented, and
   one gate line is present. No re-handoff or second pre-review unless the user asks.

3. **Human gate.** Mode comes from the invoke line: `GATE=always` (default),
   `GATE=auto`, or `GATE=assume`; anything else → stop and ask.
   - `always`: stop after every PRE_REVIEW, whatever its gate line. Open the HTML
     report (`xdg-open` / `open` / `start`) and give the human a short summary: what
     each pass changed versus the grilled plan, any scope it added, `### Assumed
     decisions`, the deferred architecture candidates, and PRE_REVIEW's own gate line
     as a hint ("pre-review says CONTINUE"). Wait for an explicit go-ahead.
   - `auto`: follow PRE_REVIEW's line. `GATE: REVIEW` → stop, summarize `### Assumed
     decisions`, the blockers, and the deferred candidates, and wait for the
     go-ahead. `GATE: CONTINUE` → go straight to IMPLEMENTATION with no pause. The
     parent never invents a gate in this mode.
   - `assume`: never pause. Go straight to IMPLEMENTATION and leave `### Assumed
     decisions` in place for Visualize.
   On a go-ahead, apply the edits the human asks for to the handoff and remove the
   Assumed decisions entries the human settled, before IMPLEMENTATION.
   Done when the user has said go, `auto` continued unpaused on `GATE: CONTINUE`, or
   `assume` continued unpaused.

4. **IMPLEMENTATION.** Before spawning, if the handoff has no `BASE:` line, record
   `BASE: $(git -C "$WORKSPACE" rev-parse HEAD)` in it (plus `BASE_DIRTY: yes` when
   WORKSPACE already had changes). POST_REVIEW diffs against it. Then spawn.
   Freeform prompt, and it must say: you are the implementer — edit code yourself; no
   nested agents (or the helper limits when this stage has helpers); do not re-run
   this skill; scope is the handoff only; an open question means stop and report it.
   Done when the implementer reports finished work within handoff scope, with any open
   question surfaced or an explicit "none".

5. **POST_REVIEW.** Two passes in one stage, same triple, same `run.sh` / native
   pattern as PRE_REVIEW: pass A runs `/thermo-nuclear-code-quality-review`, pass B
   `/code-review-matt`. Never resume an IMPLEMENTATION or FIX session for this
   stage — the reviewer needs fresh eyes.
   Shared contract: review the implementation against the handoff, append findings to
   the handoff, no fixing, no nesting (or the helper limits when this stage has
   helpers).
   - Pass A: thermo findings under `### Thermo`. No verdict line.
   - Pass B, pipeline mode: the fixed point is the handoff's `BASE:`. Nothing is
     committed before Visualize, so the diff, run in WORKSPACE, is `git diff <BASE>`
     (working tree) plus untracked files from `git status --porcelain`, not the
     three-dot range. The spec is the handoff
     itself — skip issue-tracker lookup and never ask the user. Run the Standards and
     Spec axes as parallel native subagents only when this stage has helpers;
     otherwise run them one after the other inline. Append them as `### Standards`
     and `### Spec`, not merged or reranked. `BASE:` missing → stop the stage and
     report it.
   - Pass B ends stdout **and** the handoff with the exact line `VERDICT: CLEAN` or
     `VERDICT: NEEDS_FIX`, covering all three sections.
   Approval bar: thermo must-fix or structural blockers, a hard documented-standard
   violation, or a Spec finding (missing, partial, or wrong requirement) →
   `NEEDS_FIX`. Nits, baseline smells, and scope-creep notes alone → still `CLEAN`,
   listed as optional.
   Done when all three sections are on the handoff and exactly one verdict line
   appears in both places.

6. **FIX (only on `NEEDS_FIX`).** Spawn once (defaults or `FIX=`). Prompt: fix the
   must-fix findings in the handoff post-review sections; handoff-only scope; no re-review; no
   nesting (or the helper limits when this stage has helpers); append the fix outcome
   to the handoff, with any leftovers under a `### Leftovers` heading. Leftovers are
   an acceptable outcome, not a stage failure. `CLEAN` → skip this step.
   Done when the taken branch is complete: FIX ran and appended its outcome, or the
   verdict was `CLEAN`.

7. **VISUALIZE (skipped when `VISUALIZE=off`).** First, when the handoff has
   `BASE_DIRTY: yes` and no `BASE_DIRTY_DECISION:` line: under `always` or `auto`,
   ask the human how to handle the earlier changes and record the answer as
   `BASE_DIRTY_DECISION: <answer>` in the handoff; under `assume`, stop with the
   stage failure `workspace dirty`. Then spawn once, fresh (defaults or
   `VISUALIZE=`). Prompt: run `/visualize-pr HANDOFF=<path>` (plus `--draft` when
   `DRAFT=yes`) inside the handoff's `WORKSPACE:`; no nesting (or the helper limits
   when this stage has helpers); end stdout on `PR: <url>`. `/visualize-pr` is
   user-invoked, so name it with the **loading rule**: load `/visualize-pr` with
   your skill tool; if it is not available, read
   `~/.agents/skills/visualize-pr/SKILL.md` and follow it; if that is missing too,
   stop and report. A `run.sh` spawn puts the `/visualize-pr` slash line first on
   stdin instead. `/visualize-pr` owns commit, branch, push, and
   the PR body.
   Done when the stage's last line is `PR: <url>`, or `VISUALIZE=off` skipped the
   step.

8. **Report.** Tell the user the handoff path and the outcome, plus the PR URL when
   Visualize ran. With `VISUALIZE=off`, nothing is committed and no PR is opened.
   Done when the user has the path, the result, and the PR URL when Visualize ran.

**Session-reuse gate — every `run.sh` spawn in steps 2/4/5/6** (pass A for the
two-pass stages; pass B always resumes its own pass A). Native spawns skip this gate —
always fresh. VISUALIZE (step 7) sits outside the gate: it is always a fresh spawn and
never resumes an earlier session. Before spawning, scan the
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
- Same-harness **native** subagents (Cursor `Task`, Claude Agent, …): always spawn
  fresh and record no chain entry, even when the surface exposes a resume or agent
  id.
