---
name: patrol
description: One defect patrol on a detached worktree — a Night patrol opens a draft PR, an Inspection reports in chat.
disable-model-invocation: true
argument-hint: "[night|inspect] [area] [GUARD=driverKind model [effort]] [HQ=driverKind model [effort]] [STAGE=driverKind model [effort] …]"
---

# Patrol

One run. A **Guard** roams the repo on a detached worktree, follows **Leads**, and escalates at most one **Report** to **HQ**. HQ confirms or dismisses it. A confirmed Report either runs Beer to a draft PR (**Night patrol**) or ends in chat with the Report path (**Inspection**). Anything else is **idle**.

The Patrol parent is a thin orchestrator: it runs the shell, spawns the Guard and HQ, and drives the pipeline. It reads code only through them.

## Invoke

`/patrol [night|inspect] [area] [KEY=value …]`

- **Mode.** `night` → Night patrol. Bare `/patrol` or `inspect` → Inspection.
- **Area.** The remaining bare tokens. An existing path means that path's tracked files. Anything else means the tracked paths that contain the name (case-insensitive). No area means the whole repo.
- **Keys.** `GUARD=` and `HQ=` override the **Models** rows, in both modes.
- **Pass-through (Night patrol only).** Stage model overrides (`PRE_REVIEW=`, `IMPLEMENTATION=`, `POST_REVIEW=`, `FIX=`, `VISUALIZE=<model>`) go to Beer unchanged, in Beer's shape. Patrol sets `GATE`, `DRAFT`, `HANDOFF`, `WORKSPACE`, and `RESUME` itself.
- Any of those five keys, `VISUALIZE=off`, or any key other than `GUARD=`/`HQ=` on an Inspection → `idle: bad invoke: <key>`.

Done when the mode, the area tokens, `GUARD`, `HQ`, and the pass-through list are bound.

## Models

| Role    | Default (`driverKind model [effort]`) |
| ------- | ------------------------------------- |
| `GUARD` | `claudeAgent claude-opus-5-5 medium`  |
| `HQ`    | `claudeAgent claude-opus-5-5 xhigh`   |

Beer's stages use Beer's own defaults unless the invoke line overrides them.

## Runtime

Patrol runs only in T3 Code. Without the `t3-code` tools (`orchestrator_capabilities`, `delegate_task`) → `idle: needs t3`.

**Guard and HQ** each spawn the way Beer spawns a stage (see **Spawning a stage** in `/let-me-hold-your-beer`): a fresh `delegate_task`, `mode: async`, on the role's instance, model, and effort, then end the turn until T3 wakes the parent. T3 has no read-only mode, so every Guard and HQ prompt ends with the **stage clause**, verbatim, plus the scope line:

> no nested agents and no T3 orchestration tools (delegate_task, task_*, t3_thread_*, create_threads, schedule_task). Read and search only inside `<WT>`; write nothing and run no git command that changes state.

**Write check**, after each Guard or HQ run: `git -C "$WT" status --porcelain` is empty, and `ROOT`'s HEAD and `git status --porcelain` match the step-1 snapshot. Any difference → `idle: <role> wrote files`, before anything else runs.

**Pipeline.** A confirmed Night patrol runs Beer: load `/let-me-hold-your-beer` with your skill tool, and the Patrol parent acts as Beer's parent. T3's async wake means a Night patrol spans several turns; Patrol's Cleanup and closing line come after Beer's own Report.

## Flow

Bind `ROOT` (the user's repo root) and leave `WT` unset. Every `idle: <code>` runs **Cleanup** first when `WT` is set, then ends on the closing line.

1. **Platform and snapshot.** Read the platform from `git -C "$ROOT" remote get-url origin`.
   - `bitbucket.org` → Bitbucket. `bitbucket-api` refuses any cwd outside `~/Work/mkr/`, so the parent runs every Bitbucket call from `ROOT`: check with `(cd "$ROOT" && bitbucket-api GET /user)`. Bind `BB_REPO` (`workspace/repo`) from the `origin` URL path, stripping `.git`.
   - Anything else → GitHub. `command -v gh` and `gh auth status` succeed. Bind `GH_REPO` (`owner/repo`) from `ROOT`: `gh repo view --json nameWithOwner --jq .nameWithOwner`, else parse the `origin` URL (hosts `github.com` and `github.com-*` are GitHub; take `owner/repo` from the path, strip `.git`). Pass `-R "$GH_REPO"` to every `gh` call: auto-detect from `origin` is wrong on SSH host aliases.
   - Snapshot the user's checkout: `ROOT_HEAD=$(git -C "$ROOT" rev-parse HEAD)` and `ROOT_STATUS=$(git -C "$ROOT" status --porcelain)`.

   Done when the platform tool answered and both snapshot values are bound. Otherwise `idle: gh missing` (add: install `gh`, then `gh auth login`) or `idle: bitbucket unavailable`.

2. **Worktree.**

   ```bash
   git -C "$ROOT" fetch origin
   BASE=$(git -C "$ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD) # else origin/main if it exists, else origin/master
   WT="${TMPDIR:-/tmp}/patrol-<repo>-$$"
   git -C "$ROOT" worktree add --detach "$WT" "$BASE"
   SHA=$(git -C "$WT" rev-parse HEAD)
   ```

   Done when `$WT` exists and `SHA` is set. Otherwise `idle: fetch failed`.

3. **Open patrol PRs.** List open PRs whose source branch starts with `patrol/`: title, branch, URL, and the first lines of the body.
   - GitHub: `gh pr list -R "$GH_REPO" --state open --limit 1000 --json url,title,body,headRefName` (the default page is 30), keeping `headRefName` that starts with `patrol/`.
   - Bitbucket, from `ROOT`: `bitbucket-api GET "/repositories/$BB_REPO/pullrequests?state=OPEN&pagelen=50&q=source.branch.name~%22patrol%2F%22&fields=next,values.title,values.source.branch.name,values.links.html.href,values.description"`, following `next` until it is absent. `~` means *contains*, so keep only branch names that start with `patrol/`.

   This list goes to the Guard and HQ, so a **covered** Lead costs one Lead instead of the whole run. Done when the list (possibly empty) is in hand. A failed call → `idle: <platform> failed`.

4. **Area and start file.** The parent's shell picks the start file, so runs differ. Resolve the area to paths, then draw one tracked text file at random, minus vendored, lock, and minified paths:

   ```bash
   git -C "$WT" ls-files --eol -- <area paths> \
     | awk '$1 != "i/-text" && $1 != "i/" {sub(/^[^\t]*\t/, ""); print}' \
     | grep -viE '(^|/)(vendor|node_modules|third_party|dist|build)/|\.lock$|-lock\.(json|ya?ml)$|\.min\.(js|css)$' \
     | shuf -n1
   ```

   For a name area, `<area paths>` is the output of `git -C "$WT" ls-files | grep -iF -- "<name>"`. Resolve the area set before the draw: an empty set → `idle: area not found` right there, since git reads an empty pathspec as the whole repo. Without `shuf` (macOS), end the pipe on `awk 'BEGIN{srand()} {l[NR]=$0} END{if (NR) print l[int(rand()*NR)+1]}'`. Done when one path is bound. An empty draw → `idle: area not found`.

5. **Guard.** Spawn with `GUARD`. Prompt, in order:
   1. the **Guard job**,
   2. **Report bar** and **Report shape**, pasted verbatim (the Guard sees no parent chat and never reads this file),
   3. the mode, the area, the start file, `$WT`, `SHA`, and the open-PR list,
   4. the stage clause and scope line.

   Then run the **Write check**. Done when the Guard's final message ends on `GUARD: REPORT` (with a Report above it) or `GUARD: IDLE`. `GUARD: IDLE` → `idle: nothing met the bar`. A malformed line or failed spawn → `idle: guard failed`.

6. **HQ.** Spawn with `HQ`. Prompt: the **HQ job**, the same pasted bar and shape, the Guard's Report, the mode, `$WT`, `SHA`, the open-PR list, and the stage clause and scope line. Then run the **Write check**. Done when HQ's final message ends on `HQ: CONFIRMED` with a non-empty Report above it, or `HQ: DISMISSED`. `DISMISSED` → `idle: hq dismissed`. A malformed line, failed spawn, or empty Report → `idle: hq failed`.

7. **Night patrol, confirmed.**
   - `slug` = the Report title in kebab-case, ≤ 40 chars. Run `git -C "$WT" switch -c "patrol/<slug>"`.
   - Write the handoff to `${TMPDIR:-/tmp}/patrol-handoff-<repo>-<slug>.md`: HQ's final Report, its notes under `### Seen, not acted on`, this `## Scope` paragraph verbatim, and a closing `## Suggested skills` section.

     > Night patrol: restore the intended behaviour in the Report, plus its pinning test or doc fix, and nothing else. Every architecture or product/UX change any stage notices goes under `### Seen, not acted on`, never into the plan.

   - Run the pipeline (see **Runtime**) with `HANDOFF=<path> WORKSPACE=$WT GATE=assume DRAFT=yes` plus the pass-through overrides.

   Done when the pipeline reported a PR URL, or stopped: the `workspace dirty` stage failure → `idle: workspace dirty`; any other stage failure → `idle: <stage> failed`.

8. **Inspection, confirmed.** Write HQ's final Report to `${TMPDIR:-/tmp}/patrol-report-<repo>-<slug>.md`. Its paths are repo-relative and its **HEAD** is `SHA`, because Cleanup deletes `$WT`. Give a short chat summary with the absolute path, then suggest `/grill-with-docs <path>`, followed by `/let-me-hold-your-beer HANDOFF=<path>`. Done when the run ends in chat with the Report path and summary.

9. **Cleanup** runs always: after success, idle, or failure.

   ```bash
   git -C "$ROOT" worktree remove --force "$WT" || { rm -rf "$WT"; git -C "$ROOT" worktree prune; }
   git -C "$ROOT" branch -D "patrol/<slug>"   # only if step 7 created it; after the worktree, or git refuses
   ```

   The remote branch stays when a PR exists. Done when `$WT` is gone from disk and from `git worktree list`, no local `patrol/<slug>` remains, and `ROOT`'s HEAD and `git status --porcelain` match the step-1 snapshot. Report a mismatch on the line above the closing line.

**Closing line.** A Night patrol's last output line is exactly `pr: <url>` or `idle: <reason>`. An Inspection reports in chat; an idle Inspection also ends on `idle: <reason>`. Idle reasons: `needs t3`, `bad invoke: <key>`, `gh missing`, `bitbucket unavailable`, `<platform> failed`, `fetch failed`, `area not found`, `nothing met the bar`, `guard failed`, `hq dismissed`, `hq failed`, `<role> wrote files`, `workspace dirty`, `<stage> failed`.

## Guard job

Roam `$WT` from the start file to its callers, the owning module, and the related ADRs and `CONTEXT.md`, staying inside the area. Follow up to **5 Leads**. A Lead that matches an open patrol PR is **covered**: drop it, and it still counts toward the 5. Unsure overlap counts as covered. Stop at the first Lead that clears the **Report bar** for this mode. Read and search only; write nothing.

The final message is one Report in **Report shape**, then exactly `GUARD: REPORT`; or a short reason, then exactly `GUARD: IDLE`.

## HQ job

Investigate the Guard's Report in depth on `$WT`: re-read the cited path, its callers, and the cited rule. Tighten or rewrite the Report (scenario, citations, fix intent) and record the rewrite under **HQ notes**. `CONFIRMED` only when every **Report bar** item holds for this mode. Unsure, or covered by an open patrol PR → `DISMISSED`. Read and search only; write nothing.

The final message is the final Report in **Report shape**, then exactly one last line: `HQ: CONFIRMED` or `HQ: DISMISSED`.

## Report bar

A Report clears the bar only when every item holds:

- **Scenario**: specific. Who, which boundary, what action, what goes wrong.
- **Rule**: a rule from durable docs on this SHA (ADR, `CONTEXT.md`, docs), with a pointer, or an obvious code contract.
- **Cited path**: repo-relative files and functions of that flow. For perf, the hot path and why it is expensive.
- **Defect**: the fix restores intended behaviour.

Scope by mode:

- **Both modes**: correctness, security/authz, races, measured perf, code that breaks an ADR or `CONTEXT.md` rule, missing tests on a cited risky path (the fix adds a test that pins the correct behaviour), and stale docs where the code is right and the docs or ADR describe something else (the fix corrects the docs).
- **Inspection** also weighs architecture changes and product/UX changes.
- **Night patrol** records any architecture or product/UX change it notices under **Seen, not acted on**.
- **Generated output** is reported against its source: a defect in a synced `_shared/` copy is reported against `harness/_shared/`.

## Report shape

The title, in domain language, is the first line. Then these sections, in order: **Scenario** · **Rule** (pointer) · **Cited path** · **Why this is a defect** · **Proposed fix** (intent only, no patch) · **Seen, not acted on** (optional) · **HQ notes** · **HEAD** (`SHA`).
