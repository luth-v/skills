# Explainer

One HTML page per PR, designed from scratch for this change. It is where the visuals live in full: the body links here, and on Bitbucket it is the only place they live.

## Shape

A single self-contained `.html` file: inline CSS, inline SVG, inline JS, images as `data:` URIs. Zero network requests, so it renders the same forever and leaks nothing on load.

Order the page the way a reviewer thinks:

1. **The story**: the hero animation and the one-line summary.
2. **What changed**: the visuals from `SKILL.md`, each with a heading that states its point.
3. **Evidence**: the same real proof as the body, screenshots at full size.
4. **Merge danger**: the blast radius drawn, if a picture helps.
5. **Review order**: the files as a clickable graph or list, linked to the diff.

## Style

- Light and dark from `prefers-color-scheme`, both legible.
- Motion only inside `@media (prefers-reduced-motion: no-preference)`; with reduced motion, every animation shows its final, readable frame.
- Readable with JS off: interactivity (steppers, toggles, before/after sliders, hover detail) adds depth to content that is already on the page.
- Every generated diagram carries a small "illustration" label; evidence carries its source (test name, command, date).
- Charts follow the `dataviz` skill.
- Domain language from the repo's `CONTEXT.md`, the same words as the body.
