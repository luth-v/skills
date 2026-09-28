# Bitbucket

The exception: Bitbucket renders plain Markdown only (no Mermaid, no `[!TIP]`, no inline HTML), and its content goes to no personal host. The explainer carries every visual; the body stays readable text.

## Hero

The explainer link, first line of the body:

```markdown
**▶ [Open the visual explainer](<explainer link>)**

> **In one line:** <what changes for whom>
```

This replaces both the hero image and the `[!TIP]`.

## Summary richness

Tables, code blocks, and the text views from the Summary list in `SKILL.md`. Flows that would be Mermaid on GitHub become a call tree or a numbered sequence in the body, with the full diagram in the explainer. `<details>` does not render: the review-order and reviewer-agents blocks become plain `###` sections.

## Assets

No gist, no hosted images, no marker `gist=` key. Screenshots, the hero animation, and any `--video` go inside the explainer (inline `data:` URIs or embedded SVG); a video too large for the page stays local and is reported to the user instead.

## Publisher

The installed canvas-style publisher skill for Bitbucket repos (the `artifacts` sibling that publishes to the Bitbucket org's own Share host): `publish --title "<repo> #<n>: <title>" <abs path>`, `edit <slug> <abs path>` on a re-run. When no such skill is installed, open the PR without the explainer (drop the hero link) and report it as skipped.

## PR commands

Use the `bitbucket` skill to find the PR for this branch, read its description (for the marker), create it, or update its title and description.
