# docs/agent — Agent Control Plane

Live coordination files between Brain (ChatGPT), the Primary Engineer (Claude),
and bounded operators/reviewers (Codex). Governed by [`AGENTS.md`](../../AGENTS.md)
(§9 handoff/return, §13 command bus).

## Surfaces and role separation (D-026)

| Surface | Role | Written by |
| --- | --- | --- |
| [`CURRENT_HANDOFF.md`](CURRENT_HANDOFF.md) | **Mission-level executable contract.** Non-private summary of the active handoff and what is staged / `NOT_EXECUTABLE`. Never a message log. | Brain (mirrored by Engineer) |
| [`../../TASKS.md`](../../TASKS.md) + [`../exec-plans/`](../exec-plans/) | Execution map and per-task contracts | Engineer, under Brain admission |
| [`commands/CMD-####.md`](commands/) | **Incremental Brain → Engineer instruction stream** | Brain (or Engineer transcription, see below) |
| [`returns/RET-####.md`](returns/) | **Engineer → Brain response stream**, one per answered command | Engineer |
| [`ENGINEER_RETURN.md`](ENGINEER_RETURN.md) | Latest **consolidated** engineer evidence packet for the mission | Engineer |
| [`EXECUTION_STATE.json`](EXECUTION_STATE.json) | Repo-local **mutable projection / cursor**, including command pointers. Never overrides Drive `CURRENT_EXECUTION_STATE`. | Engineer |
| [`DECISION_REQUEST.md`](DECISION_REQUEST.md) | Genuine escalations only | Any agent |

`EXECUTION_STATE.json` `status` values: `IN_PROGRESS`, `BLOCKED`,
`AWAITING_BRAIN_REVIEW`, `CHANGES_REQUIRED`, `PASS`, `IDLE`.

## Command / return protocol

### Pointers in `EXECUTION_STATE.json`

| Key | Meaning |
| --- | --- |
| `last_command_id` | Highest `CMD-####` file present. It is updated in the same change that adds the command file. |
| `last_acknowledged_command_id` | Highest command the Engineer has acknowledged, or `null`. Always ≤ `last_command_id`. |
| `last_return_id` | Highest `RET-####` file present, or `null`. |
| `command_processing_status` | `IDLE` (no commands, or all answered and nothing new), `UNREAD` (`last_command_id` > `last_acknowledged_command_id`), `ACKNOWLEDGED` (at least one acknowledged command is still open), `ANSWERED` (every acknowledged command has a final return and nothing is unread), `BLOCKED` (an acknowledged command cannot proceed; see its return or Decision Request). |
| `command_ledger` | `{ "CMD-####": { "status": "ACKNOWLEDGED" \| "ANSWERED" \| "BLOCKED", "return_id": "RET-####" \| null, "partial_return_ids": ["RET-####", …] } }` for every acknowledged command. `partial_return_ids` lists interim `Disposition: PARTIAL` checkpoint returns. A cumulative return (CMD-0009) answers its `Answers` command and every earlier command listed in its optional `Also answers:` field; each of those ledger entries then records that return. |

### Semantics

1. **Unread check.** At session start, after the read order in `CLAUDE.md`,
   the Engineer compares `last_command_id` with `last_acknowledged_command_id`
   and lists `commands/`. If a `CMD` file exists that is above the pointer, it is
   unread even when a pointer was not updated. The files on disk are the truth,
   and the validator flags pointer drift.
2. **Acknowledge.** Before material work on `CMD-n`, the Engineer sets
   `last_acknowledged_command_id = CMD-n`, adds `command_ledger[CMD-n] =
   {status: ACKNOWLEDGED, return_id: null}`, and sets
   `command_processing_status = ACKNOWLEDGED`. This can be in the first commit
   of the work. Acknowledgement means "read and accepted for processing", not
   "done". Commands are acknowledged in ID order, and none is skipped.
3. **Answer.** The Engineer writes the next free `returns/RET-m.md` with
   `Answers: CMD-n`, sets `command_ledger[CMD-n] = {status: ANSWERED,
   return_id: RET-m}`, `last_return_id = RET-m`, and
   `command_processing_status = ANSWERED` (or `UNREAD` if newer commands exist),
   and refreshes `ENGINEER_RETURN.md`.
4. **Checkpoint (PARTIAL) returns.** For a long-running command, such as a
   whole mission, the Engineer may issue interim `RET` records with
   `Disposition: PARTIAL`. They are listed in `partial_return_ids`. The command
   stays `ACKNOWLEDGED`, and `command_processing_status` stays `ACKNOWLEDGED`,
   until a non-PARTIAL return answers it.
5. **Refuse / block.** If a command is out of scope, requires a protected
   action, or conflicts with canonical authority, the Engineer still answers it
   with a `RET` whose disposition is `BLOCKED` or `REJECTED_COMMAND`, with the
   reason and a Decision Request where one is needed. Ledger status is `BLOCKED`.
6. **Immutability.** Pushed `CMD` / `RET` files are never edited in meaning or
   renumbered. A correction is a new record with `Supersedes:`.
7. **Executability guard.** No command makes a `NOT_EXECUTABLE` handoff
   executable implicitly (see [`commands/README.md`](commands/README.md#executability-guard)).

### Transport and wake-up

- **Preferred:** Brain commits `CMD-####.md` directly.
- **Otherwise:** Brain issues the instruction through Drive, a GitHub `@claude`
  comment, or, as an exception, a Founder-relayed session. The Engineer
  transcribes it with the same meaning into the next free `CMD` file
  (`Recorded by: Engineer (transcription)`, `Source:` cited).
- **Wake-up:** `.github/workflows/claude-bridge.yml` (LA-0008) starts a Claude
  run when a trusted repository role mentions `@claude`. It only wakes the
  Engineer. The run follows the read order and processes unread `CMD` records.
  The triggering comment is not itself a command. If the bridge is unavailable,
  commands stay durable and are processed at the next Claude session.
- **The Founder is not the routine courier.** Manual relay is reserved for
  provider-required interactive authorization or other protected human actions.

### Recovery

- **Pointer drift** (validator failure): the files on disk are authoritative.
  Fix the pointers to match them in a separate commit, and note it in the next
  `RET`.
- **Interrupted session** (`ACKNOWLEDGED` with no return): the next session
  resumes that command before any newer one.
- **Conflicting commands:** process them in ID order. If a later command
  contradicts an earlier one without `Supersedes:`, answer with `BLOCKED` and
  ask Brain.

These files must never contain secrets, personal data, local machine paths, or
private Drive content.
