# docs/agent/returns — Engineer → Brain response stream

Engineer-owned, append-only records, one per answered command (D-026,
[`AGENTS.md` §13](../../../AGENTS.md#13-brain--engineer-command--return-bus-d-026)).
The latest consolidated evidence packet stays in [`../ENGINEER_RETURN.md`](../ENGINEER_RETURN.md).

## Naming

`RET-####.md`. The number is four digits, starts at `RET-0001`, and increases by
exactly one per record. IDs are never reused, skipped, or renumbered. The
validator enforces this.

## Required fields

Each record begins with `# RET-#### — <title>` and then this field list, one per
line, in the form `- Label: value`:

| Field | Meaning |
| --- | --- |
| `Return ID` | Same as the file name. |
| `Answers` | The `CMD-####` it answers. That file must exist. |
| `Sender` | `Claude (Primary Engineer)`. |
| `Date` | `YYYY-MM-DD`. |
| `Repository` | `Jay-prodesign/sesli-ogren`. |
| `Branch` | Working branch. |
| `Base SHA` | 40-hex. |
| `Head SHA` | 40-hex head the evidence was produced at. A commit cannot contain its own SHA (CMD-0009), so a final-review return may instead use `PR_HEAD_AT_REVIEW` together with `Head binding: GITHUB_PR_HEAD`. That is allowed only with a `…READY_FOR_BRAIN_REVIEW` disposition and, for the latest return, an `EXECUTION_STATE.json` in AWAITING_BRAIN_REVIEW with the same binding. Brain then resolves the exact SHA from the PR and its CI runs. |
| `PR` | `#n` or `none`. |
| `Disposition` | `READY_FOR_BRAIN_REVIEW` (or a mission-specific label such as `BOOTSTRAP_READY_FOR_BRAIN_REVIEW`), `BLOCKED`, `PARTIAL`, or `REJECTED_COMMAND`. |
| `Supersedes` | `RET-####` or `none`. |
| `Head binding` | Optional. `GITHUB_PR_HEAD`; required when `Head SHA` is `PR_HEAD_AT_REVIEW`. |
| `Also answers` | Optional, cumulative returns only. A comma-separated list of earlier `CMD-####` that this non-PARTIAL return also answers. |

Required sections follow: `## Work performed`, `## Tests / validation`, `## CI`,
`## Deviations`, `## Blockers`.
