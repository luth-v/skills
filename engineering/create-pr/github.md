# GitHub

The default platform: the body itself is rich.

## Hero

A single animated SVG that tells the change as a story in a few seconds, with `alt` text that says the same story in words:

```html
<p align="center">
  <img src="https://gist.githubusercontent.com/<user>/<gist id>/raw/hero.svg" alt="<the story in one or two sentences>" width="100%">
</p>

<p align="center">
  <b><a href="<explainer link>">▶ Open the interactive explainer</a></b>
</p>
```

With `--video`, add `<b><a href="<video link>">🎬 Watch the video</a></b> ·` before the explainer link.

GitHub serves the SVG through an image proxy: CSS and SMIL animation play, scripts and external fonts or images do not. Keep it self-contained, legible on light and dark backgrounds, and wrap the motion in `@media (prefers-reduced-motion: no-preference)`.

## Summary richness

Use what GitHub renders:

- Mermaid (`sequenceDiagram`, `flowchart`, `stateDiagram-v2`) for flows, with `classDef` to colour kept vs dropped, success vs failure.
- Tables for who-sees-what, endpoints, error codes.
- `<details>` for depth a reviewer may skip: rejection rules, edge cases, the reason behind a lock or a retry.
- Emoji in section headings (`## 🎯 What this does`) as signposts.
- Review-order links: `https://github.com/<owner>/<repo>/pull/<n>/files#diff-<sha256 of the path>`. Before the PR exists, link the file path on the branch and switch to the files-tab link on update.

## Assets: one secret gist per PR

A secret gist is unlisted: absent from your profile and search, readable by anyone holding the URL. Hold it to the same standard as the explainer: scrubbed before upload.

- Create: `gh gist create --desc "<repo>#<branch> PR assets" hero.svg` (secret by default). Record the gist ID in the marker.
- Update text files: `gh gist edit <id> -f hero.svg <path>`, or `-a <path>` to add one.
- Binary files (screenshots, the video) need git, because `gh gist` takes text only:

  ```bash
  git clone https://gist.github.com/<id>.git /tmp/create-pr/gist-<id>
  cp shot-before.png shot-after.png /tmp/create-pr/gist-<id>/
  git -C /tmp/create-pr/gist-<id> add -A && git -C /tmp/create-pr/gist-<id> commit -m assets && git -C /tmp/create-pr/gist-<id> push
  ```

- Embed with `https://gist.githubusercontent.com/<user>/<id>/raw/<file>`. With no commit SHA in the URL it always serves the latest push (cached for a few minutes), so an Edit never needs a body change.

A video's raw URL downloads rather than plays; link it, with the hero or a still as the thumbnail.

## Publisher

The `artifacts` skill: `publish --title "<repo> #<n>: <title>" <abs path>` for a new Share, `edit <slug> <abs path>` on a re-run. The handoff goes out the same way as a `.md` file.

## PR commands

- Create: `gh pr create --title "<title>" --body-file /tmp/create-pr/<repo>-<branch>/body.md --base <base>`.
- Update: `gh pr edit <n> --title "<title>" --body-file <same>`.
- Read the marker: `gh pr view --json body -q .body`.
