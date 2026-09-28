---
name: create-pr
description: Write a visual, fast-to-review PR body with a published explainer, then open or update the PR.
disable-model-invocation: true
argument-hint: "[--video] [HANDOFF=/path]"
---

# /create-pr

Turn the current branch into a PR a human can review fast: a rich body, an interactive **explainer** page, and (after `/let-them-cook`) the published handoff for the reviewer's agent.

## Platform

Read the `origin` remote once:

- **Bitbucket** (`bitbucket.org`) is the exception: read [`bitbucket.md`](bitbucket.md).
- Everything else is **GitHub**, the default: read [`github.md`](github.md).

The platform file owns the hero, asset hosting, the publisher, and the PR commands. Everything below applies to both.

## Flow

1. **Gather.** Diff against the base branch, the commits, `CONTEXT.md` for domain language, and the repo's recent PR titles for the title style. Look for an existing PR on this branch; if one exists, read the `create-pr` marker from its body (see [Marker](#marker)). Done when you can say what changed, why, and what it could break.
2. **Find the handoff.** Use `HANDOFF=/path`, else a handoff path mentioned in this conversation. None found → skip it; never guess one from disk.
3. **Draft in `/tmp/create-pr/<repo>-<branch>/`**: `body.md`, `explainer.html` (read [`explainer.md`](explainer.md)), the hero and any screenshots, and the redacted handoff copy. Done when every file exists and the body's links are placeholders.
4. **Scrub.** Every file bound for publishing is free of secrets, tokens, customer data, production hostnames or values, and personal data. Replace real values with obvious fakes. When in doubt, redact or fake it; never stop to ask.
5. **Publish.** No confirmation: publish as soon as the scrub is done. In order: assets per the platform file, the explainer, the handoff (as Markdown). Re-runs Edit the existing gist and Shares named in the marker, overwriting them. Fill the real links into `body.md` and write the marker.
6. **Open or update the PR** with the platform file's commands (a re-run overwrites the live title and body), then link the PR in this thread if a PR-linking tool is available. Report the PR URL, each published link, and anything skipped.

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

<details>
<summary><b>🧭 Review order</b></summary>

1. [`path/to/entry.ts`](<files-tab link>): <why first>
2. ...

</details>

<details>
<summary><b>🤖 For reviewer agents</b></summary>

Handoff from the implementing session: <handoff link>

</details>

<!-- create-pr: gist=<id> explainer=<slug> handoff=<slug> -->
```

Drop the reviewer-agents block when there is no handoff. Bitbucket has no `[!TIP]`; its file gives the substitute.

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

- **Behaviour over time**, animated only when order or timing is the point: request or event flow before vs after, races, retries, state machine transitions.
- **Structure diffs**: module or service graphs with changed nodes coloured and the blast radius shaded.
- **Data shape**: schema or migration before/after, API contract changes, field mappings.
- **UI**: before/after screenshots, a Playwright trace of the new flow.
- **Numbers**: performance, bundle size, query counts before vs after, charted with the `dataviz` skill.
- **Review order**: which files to read first, and why.

Each visual makes one point. A visual that replays the diff line by line, or decorates, gets cut.

## Marker

The PR body is the only record of what was published. The last line of the body is:

```html
<!-- create-pr: gist=<gist id> explainer=<share slug> handoff=<share slug> -->
```

Omit a key that has no value (`gist` is GitHub only). A re-run reuses every ID it finds and creates only the missing ones.

## `--video`

Only when passed: a narrated motion-graphic walkthrough of the PR, under about a minute, hosted per the platform file and linked beside the explainer. Without the flag, no video.
