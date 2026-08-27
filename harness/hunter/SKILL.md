---
name: hunter
description: One-tick defect hunter — file at most one GitHub take ticket or idle.
disable-model-invocation: true
argument-hint: "[area] [WARDEN=harness model [effort]]"
---

# Hunter

One **tick**. At most one GitHub issue labeled `hunter`, or **idle**. Restore intended behavior (correctness, security/authz, races, measured perf). Do not implement the fix.

**Warden** confirms the take before file. You are the parent.

## Invoke

Parse the invoke line.

- `WARDEN=harness model [effort]` — optional. Default = the `PRE_REVIEW` row in `$HOME/.agents/skills/let-them-cook/SKILL.md` (same shape as Cook `PRE_REVIEW=`). If that file is missing, `cursor claude-fable-5-thinking-high`.
- Remaining tokens = **area**. Empty area → hot-spot. Non-empty → stay in that path/module/name; if nothing there meets **Finding**, idle (do not switch area).

Done when `WARDEN` and `area` are bound.

`WT` starts unset. **idle** `<code>` = if `WT` is set, run **Cleanup**; print exactly one line `idle: <code>` (for `gh missing`, add: install `gh`, then `gh auth login`); stop. Tick is done.

## Tick

### 1. Tools

`command -v gh` and `gh auth status` (github.com) both succeed.

Done: both succeeded, continue. Else `idle: gh missing`.

### 2. Repo

From the user's repo root, bind `GH_REPO` (`owner/repo`):

1. `gh repo view --json nameWithOwner --jq .nameWithOwner`
2. Else parse `git remote get-url origin`. Hosts `github.com` and `github.com-*` are GitHub; take `owner/repo` from the path; strip `.git`.

Every later `gh` call uses `-R "$GH_REPO"` (auto-detect from origin is wrong on SSH host aliases). Any of those calls failing → `idle: gh failed`.

Done: `GH_REPO` is set. Else `idle: not github`.

### 3. Cap

If label `hunter` is absent, `gh label create hunter -R "$GH_REPO"`. Then count `gh issue list -R "$GH_REPO" --label hunter --state open`.

Done: count is an integer. Count `>= 5` → `idle: cap full`. Count `< 5` → continue.

### 4. Fetch

From the user's repo root: `git fetch origin`. Do not `checkout`, `pull`, or `reset` the user's worktree.

Bind `BASE` = `git symbolic-ref --quiet --short refs/remotes/origin/HEAD`, else `origin/main` if that ref exists, else `origin/master`.

Done: `BASE` resolves. Else `idle: fetch failed`.

### 5. Worktree

```bash
WT="${TMPDIR:-/tmp}/hunter-${GH_REPO##*/}-$$"
git worktree add --detach "$WT" "$BASE"
SHA=$(git -C "$WT" rev-parse HEAD)
```

Hunter reads and Warden `--cd` **only** `$WT` (docs and code from that SHA).

Done: `$WT` exists, `SHA` is set.

### 6. Ledger

`gh issue list -R "$GH_REPO" --label hunter --state open` with title and body. Those **invariant + path** pairs are taken. Unsure overlap → taken.

Done: open takes are in hand.

### 7. Hunt

Pick one area: invoke `area`, or (bare `/hunter`) a churn-heavy path from `git log "$BASE" -30 --name-only` on this worktree.

Read that flow on `$WT`. Read matching durable docs on `$WT` if present (`CONTEXT.md`, `docs/context/`, `docs/adr/`, `docs/**/adr/`) as the invariant source. Apply every item in **Finding**. Produce **one** candidate (scenario, invariant, cited path, issue draft) or none.

Done: one candidate that meets **Finding** and is not a taken pair, or `idle: nothing met the bar`.

### 8. Warden

Read `_shared/parent-harness-contract.md` beside this SKILL.md (installed: `$HOME/.agents/skills/hunter/_shared/parent-harness-contract.md`) and the target harness `SKILL.md`. Spawn through that harness `run.sh` (not a native task tool). Fresh session — no `--resume`. Helpers off (`no nested agents` in the prompt). No `/thermo-nuclear-code-quality-review` on stdin.

`--cd "$WT"` when the contract table says yes. `--model` (and `--effort` only if that harness exposes it; cursor effort lives in the model slug).

Stdin, in order:

1. The Warden job paragraph in **Warden**.
2. **Finding** and **Issue** pasted verbatim from this file.
3. Candidate: scenario, invariant, cited path, issue draft, `SHA`, worktree path.
4. Output contract in **Warden**.

Wait on the run (high `block_until_ms`; note `LOG=`). Spawn fail, crash, or empty stdout → `idle: warden failed`.

Done: stdout captured.

### 9. Verdict

Last line of Warden stdout is exactly `VERDICT: FILE` or `VERDICT: NO_FILE`. Anything else → `idle: warden failed`. `NO_FILE` → `idle: warden NO_FILE`.

`FILE`: issue draft = stdout above that line. Empty draft → `idle: warden failed`.

Done: draft ready to file.

### 10. File

```bash
gh issue create -R "$GH_REPO" --label hunter --title "<draft first line>" --body "<draft remainder>"
```

Done: command printed an issue URL. Else `idle: gh failed`.

### 11. Cleanup and report

Run **Cleanup**. Print the issue URL (and only that as the outcome line). Tick is done.

## Cleanup

```bash
git worktree remove --force "$WT" || { rm -rf "$WT"; git worktree prune; }
```

Done: `$WT` is gone from disk and `git worktree list`. User checkout is unchanged.

## Finding

File only if every item holds:

- **Scenario** — who, which authz or data boundary, action, what goes wrong. Specific.
- **Invariant** — a rule in durable docs on this SHA, or an obvious code contract.
- **Cited path** — files/functions of that flow. Perf: the hot path and why it is expensive (unbounded list, N+1, missing index on a real query).
- **Defect** — restoring intended behavior.

A take is none of: generated output, missing tests, docs-only drift, architecture deepening, product/UX change. Tests may be cited as evidence. Docs are the invariant source.

No directory allowlist.

## Issue

Label `hunter` only.

Title: short defect in domain language. Draft first line = title; remainder = body.

Body, this order: **Scenario** · **Invariant** (doc/ADR/code pointer) · **Cited path** · **Why this is a defect** · **Proposed fix** (intent, no patch) · **Warden** (`FILE` + rewrite notes) · **HEAD** (`$BASE` SHA).

## Warden

Job: re-read the cited flow on the worktree. `FILE` only if every **Finding** item holds. Unsure → `NO_FILE`. May rewrite the draft (tighter scenario, citations). Must not edit product code or turn the take into architecture or product work.

Stdout = final issue draft (title + body per **Issue**), then exactly one last line `VERDICT: FILE` or `VERDICT: NO_FILE`.
