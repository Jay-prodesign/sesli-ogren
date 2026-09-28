# docs/agent — Agent Control Plane

Live coordination files between Brain (ChatGPT), the Primary Engineer (Claude),
and bounded operators/reviewers (Codex). Governed by [`AGENTS.md`](../../AGENTS.md).

| File | Written by | Purpose |
| --- | --- | --- |
| [`CURRENT_HANDOFF.md`](CURRENT_HANDOFF.md) | Brain (mirrored by Engineer) | Non-private summary of the active handoff and what is staged / not executable |
| [`EXECUTION_STATE.json`](EXECUTION_STATE.json) | Engineer | Machine-readable state: mission, status, git refs, PR, next handoff |
| [`ENGINEER_RETURN.md`](ENGINEER_RETURN.md) | Engineer | Evidence and verdict for the current mission |
| [`DECISION_REQUEST.md`](DECISION_REQUEST.md) | Any agent | Open questions needing Brain / Product Owner decision |

`EXECUTION_STATE.json` `status` values: `IN_PROGRESS`, `BLOCKED`,
`AWAITING_BRAIN_REVIEW`, `CHANGES_REQUIRED`, `PASS`, `IDLE`.

These files must never contain secrets, personal data, local machine paths, or
private Drive content.
