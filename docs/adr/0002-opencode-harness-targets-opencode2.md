# OpenCode harness targets OpenCode 2

The harness remains named `opencode` for a stable parent–harness contract but executes `opencode2 run --standalone` so automated runs use the v2 CLI without sharing the interactive TUI's background service. It does not fall back to v1 because silently switching CLI generations would change command and session semantics.

## Considered options

- Rename the harness to `/opencode2` — rejected because the harness identity is part of the parent-facing contract.
- Fall back to v1 when `opencode2` is unavailable — rejected because the two CLIs have incompatible flags and session behavior.
- Share the background service — rejected to isolate harness runs from the interactive TUI.
