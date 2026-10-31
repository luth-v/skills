---
name: visualize-pr
description: Commit the reviewed work, then open or update a visual, fast-to-review PR with a published explainer.
disable-model-invocation: true
argument-hint: "[--draft] [HANDOFF=/path]"
---

# /visualize-pr

Turn the current work into a PR a human can review fast: a rich body, an interactive **explainer** page that opens on a motion graphic, and (after a Cook or Hold) the published handoff for the reviewer's agent.

## Platform

Read the `origin` remote once:

- **Bitbucket** (`bitbucket.org`) is the exception: read [`bitbucket.md`](bitbucket.md).
- Everything else is **GitHub**, the default: read [`github.md`](github.md).

The platform file owns the hero, asset hosting, the publisher, and the PR commands. Everything below applies to both.

## Flow

1. **Find the handoff.** Use `HANDOFF=/path`, else a handoff path mentioned in this conversation. None found → skip it; never guess one from disk. Work in the handoff's `WORKSPACE:` when it has one, else the repo root of the cwd. Done when the handoff and the workspace are bound, or there is no handoff.
2. **Commit.** Runs when the handoff has a `BASE:` line (a Cook or Hold run) and the workspace has changes since `BASE`. With no `BASE:` line, use the branch as it is.
   - `BASE_DIRTY: yes` with no `BASE_DIRTY_DECISION:` line → commit nothing. Ask the user how to handle the earlier changes (a pipeline parent records that answer before it spawns this stage). A `BASE_DIRTY_DECISION:` line → follow it.
   - On the default branch or a detached HEAD, first `git switch -c <branch>`, named from the handoff title (kebab-case, ≤ 40 chars).
   - Stage the pipeline's changes path by path: `git diff --name-only --no-renames <BASE>` (so a rename stages both its old and new path) plus the untracked (`??`) files from `git status --porcelain --untracked-files=all` (one entry per file, so every new file inside a new directory passes the filter below), each through `git add -- <path>`. Leave out secrets and build artefacts, and name them in the report.
   - Make one commit in the style of the repo's `git log`.

   Done when the reviewed set is committed, or there was nothing to commit.
3. **Gather.** Diff against the base branch, the commits, `CONTEXT.md` for domain language, and the repo's recent PR titles for the title style. Look for an existing PR on this branch; if one exists, read the `visualize-pr` marker from its body (see [Marker](#marker)). Done when you can say what changed, why, and what it could break.
4. **Draft in `/tmp/visualize-pr/<repo>-<branch>/`**: `body.md`, `explainer.html` (read [`explainer.md`](explainer.md)), the motion graphic and any screenshots, and the redacted handoff copy. Done when every file exists and the body's links are placeholders.
5. **Scrub.** Every file bound for publishing is free of secrets, tokens, customer data, production hostnames or values, and personal data. Replace real values with obvious fakes. When in doubt, redact or fake it; never stop to ask.
6. **Publish.** No confirmation: publish as soon as the scrub is done. In order: assets per the platform file, the explainer, the handoff (as Markdown). Re-runs Edit the existing gist and Shares named in the marker, overwriting them. Fill the real links into `body.md` and write the marker.
7. **Open or update the PR.** Push first: `git push -u origin HEAD` when the branch has no upstream or is ahead. Then use the platform file's commands; a re-run overwrites the live title and body and leaves the PR's draft state as it is. `--draft` opens a new PR as a draft. Link the PR in this thread if a PR-linking tool is available. Report the PR URL, each published link, and anything left out or skipped, then end on `PR: <url>`. Done when the PR exists with the new body and the last line is `PR: <url>`.

## Body

Skip preambles. Keep prose brief. Every PR, both platforms:

```markdown
<hero, per platform file>

> [!TIP]
> **In one line:** <what changes for whom>

## Summary

<the rich sections: tables, flows, diagrams, per platform file>

## Evidence

- **Before:** <failing test / output / screenshot>
  **After:** <passing test / output / screenshot>

## Merge Danger

**Door:** <one-way or two-way>

**Blast Radius:** <one word>

<ramifications, if any>

## Assumed decisions

<from the handoff, when present>

## Leftovers

<from the handoff, when present>

<details>
<summary><b>🧭 Review order</b></summary>

1. [`path/to/entry.ts`](<files-tab link>): <why first>
2. ...

</details>

<details>
<summary><b>🔭 Seen, not acted on · deferred architecture</b></summary>

<the handoff's `### Seen, not acted on` and `### Deferred architecture candidates`, when present>

</details>

<details>
<summary><b>🤖 For reviewer agents</b></summary>

Handoff from the implementing session: <handoff link>

</details>

<!-- visualize-pr: gist=<id> explainer=<slug> handoff=<slug> -->
```

Drop the reviewer-agents block when there is no handoff, and each reviewer-note section the handoff lacks. Bitbucket has no `[!TIP]`; its file gives the substitute.

### Reviewer notes

The handoff's own headings feed the body: `### Assumed decisions` and `### Leftovers` become visible sections after Merge Danger, so the reviewer settles what no human confirmed. `### Seen, not acted on` and `### Deferred architecture candidates` go in the collapsed block (plain `###` sections on Bitbucket). Hold and Cook pass only `HANDOFF=`; this is the one place that knows these headings.

### Summary

Pick the smallest views that make the key point clear, each placed next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to understand the change. Use one, use several, never all.

- Logic or an algorithm → pseudocode.
- Runtime control flow → a call tree (`submitForm` → `createSession` → `persistPrompt`).
- UI structure → a component tree with the state and module boundaries that matter.
- File responsibility or a broad refactor → a shallow file tree with one-line comments.
- Interaction, control flow, or data flow → a sequence or flow diagram (format per platform file).
- What changed inside a shape that already exists → a `diff` block matched to that shape: component tree, file tree, call tree, or state flow, with `+`/`-` on the changed lines.
- Mostly new code, or order that matters → the whole block.

### Evidence

Real proof only: a test that failed and now passes (shown as pseudocode), console output, screenshots, a Playwright trace. Screenshots are the strongest when the change is visual and the environment can take them. A diagram you drew is a claim, never evidence.

### Merge Danger

A two-way door is cheap to roll back; a one-way door is not (destructive migrations, data deletion, published contracts). The blast radius is everything the change could break: consumers, layout, mobile, jobs, other services.

## Visuals

Generated visuals are **claims, not evidence**: label them as illustrations, and keep proof in Evidence.

A visual earns its place when it shows what the diff cannot show at a glance:

- **Behaviour over time**, beyond the opening motion graphic, animated only when order or timing is the point: request or event flow before vs after, races, retries, state machine transitions.
- **Structure diffs**: module or service graphs with changed nodes coloured and the blast radius shaded.
- **Data shape**: schema or migration before/after, API contract changes, field mappings.
- **UI**: before/after screenshots, a Playwright trace of the new flow.
- **Numbers**: performance, bundle size, query counts before vs after, charted with the `dataviz` skill.
- **Review order**: which files to read first, and why.

Each visual makes one point. A visual that replays the diff line by line, or decorates, gets cut.

## Marker

The PR body is the only record of what was published. The last line of the body is:

```html
<!-- visualize-pr: gist=<gist id> explainer=<share slug> handoff=<share slug> -->
```

Omit a key that has no value (`gist` is GitHub only). A re-run reuses every ID it finds and creates only the missing ones.
