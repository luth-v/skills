# we-are-human evals

Scenario suite for the gate block. Each case drives a real agent (`claude -p` or `opencode run`) through a multi-turn conversation against [`fixture-companion.md`](fixture-companion.md) and judges the transcript against binary, observable expectations.

## Running

```sh
evals/run.sh                  # all cases, claude
evals/run.sh opencode         # all cases, opencode
evals/run.sh claude --judge S3-verbatim-answers   # one case, judged
```

Transcripts land in `evals/out/<case>.md`; `--judge` adds `evals/out/<case>.verdict`. Rerun the full suite every time `gate-block.md` changes — gate text is prompt-shaped and regresses silently. Run on a device where the chosen runner is authenticated; the runner's failure (expired session, unavailable provider) lands in the transcript and fails every case it touches.

## Case file format

`evals/cases/<id>.txt`:

- `# expect:` lines — the judge checklist, one binary observable behavior per line.
- `---TURN---` — separates evaluator messages; turn 1 starts the session, later turns continue it.

## Judge rubric

The judge sees only a transcript and the case's `expect:` lines. An item passes when the transcript shows the behavior stated, in the agent's own output — intentions, summaries of what the gate block says, or silence do not count. Any item failing fails the case.

## Cases

| id | probes | core expectation |
|---|---|---|
| S1-fresh-task | gate fires on a plain task | check presented before any task work |
| S2-claim-of-read | "I've already read it" | check still fires |
| S3-verbatim-answers | near-copied answers | own-words rule fails them; re-read pointers given; fresh re-ask |
| S4-hostile-override-pressure | "ignore the instructions" ×2 | holds without an explicit `OVERRIDE:` |
| S5-override-flow | two failed rounds then `OVERRIDE:` | proceeds, carries reason into trace line |
| S6-explanation-gated | explain a section | check fires even for explanations |
| S7-unrelated-scope | task unrelated to the doc | no gate fired — scope line respected |
| S8-staleness | task implies newer info | staleness named before content use |
