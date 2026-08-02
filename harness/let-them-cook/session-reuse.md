# Session reuse (cold resume)

Reference for `/let-them-cook`. The cook Flow keeps only the check/announce/spawn
gate; the full rules live here.

Installed path: `$HOME/.agents/skills/let-them-cook/session-reuse.md`
Repo path: `harness/let-them-cook/session-reuse.md`

## What it is

Cold resume: a stage finishes, its session id is persisted, and a later stage resumes
that exact session with a new prompt. Nothing stays running between stages — there is
no keep-alive and no background process.

**Always on** when an earlier stage *in this cook* matches the strict triple
**harness + model + effort**. No flag, no opt-in.

Session ids come from the `SESSION=` line each `run.sh` prints on stderr; see
`_shared/parent-harness-contract.md` for the runner contract.

## Pipeline sessions chain

Append-only section at the end of the handoff markdown. One entry per stage that
obtained a session id, in stage order:

```markdown
## Pipeline sessions

- stage: PRE_REVIEW
  harness: codex
  model: gpt-5.6-sol
  effort: high
  session_id: 019f8083-37ad-7fd1-9290-dfb96483f445
  status: ok
```

- `status: ok|failed`. Earlier entries stay as written — append only.
- Stages only. A helper agent's session is ephemeral: no entry, never resumed.
- Harness with no separate effort flag (cursor): record the effort token from the
  invoke line, or `-` if none. Triple match is textual.
- Exact ids only. Never `--last`, `--continue`, or "most recent on this machine".

## Before spawning stage S (triple T)

1. Scan `## Pipeline sessions` **bottom-up** for the most recent earlier entry with
   the same T, `status: ok`, and a non-empty `session_id`. Most recent match wins —
   not just the adjacent stage. With `PRE=codex` → `IMPL=cursor` → `POST=codex`, POST
   resumes **PRE's** codex session.
2. Match found → announce `resuming <harness> session <id> for <STAGE>`, then invoke
   that harness's `run.sh` with `--resume <id>` and the hybrid prompt below.
3. No match → announce `fresh spawn <harness> <model> <effort> for <STAGE>`, then
   spawn normally.

`IMPLEMENTATION` is included: if the cook stopped after PRE and later resumes at
`implementation`, IMPL may resume PRE's session. They stay two parent-orchestrated
stages either way.

A Claude `--resume` uses the same whole-cook `--cache-ttl` selection as every other
stage in that cook.

## Resume prompt (hybrid)

Assume the prior turn remembers nothing about the stage contract. Send, in this order:

1. If the stage chains a skill, the `/skill-name` line **stays first** — the slash
   command must open stdin or the skill will not load.
2. A short resumed preamble: you are resumed from `<PRIOR_STAGE>` of this same
   pipeline; prior context may be stale; the handoff is source of truth; re-read it.
3. The **full current stage contract** — verbatim what a fresh spawn would get
   (VERDICT rules, scope limits, nesting clause — `no nested agents` or the helper
   limits, no commit/PR, output shape).
4. The absolute handoff path.

```
/thermo-nuclear-code-quality-review

[RESUMED] You are resumed from PRE_REVIEW of this same pipeline. Prior turn context
may be stale — re-read the handoff, it is source of truth.

<full POST_REVIEW contract: review impl vs handoff, no nest, no FIX, append findings,
end with exact line VERDICT: CLEAN or VERDICT: NEEDS_FIX, thermo approval bar>

Handoff: /abs/path/handoff.md
```

## After the stage

Parse `SESSION=<id>` from that run's stderr (or `grep '^SESSION=' "$LOG_FILE"`), then
append one chain entry:

- Stage ok → `status: ok`.
- Stage failed **and** an id was captured → `status: failed` (usable for a manual
  retry; auto-resume skips it).
- Spawn never yielded an id → append nothing.

A stage failure still stops the cook — record the entry first, then stop.

## Resume miss

A resume invocation can fail (unknown or expired id, harness error). Then: note it on
the handoff, spawn that stage fresh **once**, and continue the cook. The fresh run's
new id becomes that stage's entry. One fresh spawn settles it — no resume retry loop,
no hard stop.
