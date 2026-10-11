# docs/agent/commands — Brain → Engineer command stream

Brain-owned, append-only records of incremental instructions within a mission
(D-026, [`AGENTS.md` §13](../../../AGENTS.md#13-brain--engineer-command--return-bus-d-026)).
The mission contract itself stays in [`../CURRENT_HANDOFF.md`](../CURRENT_HANDOFF.md).

## Naming

`CMD-####.md`. The number is four digits, starts at `CMD-0001`, and increases by
exactly one per record. IDs are never reused, skipped, or renumbered. The
validator enforces this.

## Required fields

Each record begins with `# CMD-#### — <title>` and then this field list. Use
exactly these labels, one per line, in the form `- Label: value`:

| Field | Meaning |
| --- | --- |
| `Command ID` | Same as the file name. |
| `Sender` | `Brain`. |
| `Recipient` | `Claude (Primary Engineer)`. |
| `Recorded by` | `Brain`, or `Engineer (transcription)` when Brain delivered the instruction through another channel. |
| `Source` | Where the instruction came from, for example a Drive document title, a GitHub comment URL, or a session relay. |
| `Issued` | `YYYY-MM-DD`. |
| `Mission` | Handoff ID, for example `CLAUDE_HANDOFF_000`. |
| `Tasks` | `LA-####` IDs in scope. |
| `PR` | `#n` or `none`. |
| `Head at issue` | 40-hex SHA the command was written against, or `none`. |
| `Supersedes` | `CMD-####` or `none`. |
| `Executability change` | `none`, or an explicit `<HANDOFF_ID> -> READY` (see guard below). |
| `Gate evidence` | `none`, or the Brain PASS verdict reference that authorizes an executability change. |
| `Status` | Issuance status: `ISSUED`. The live processing status is tracked in `EXECUTION_STATE.json` `command_ledger`, so the command file stays immutable. |

Sections that follow: `## Instruction` and `## Expected return`.

## Executability guard

A command cannot make a `NOT_EXECUTABLE` handoff executable implicitly. The
validator fails when either of these holds:

- `Executability change` is not `none`, but `Gate evidence` does not cite a PASS
  verdict, or `CURRENT_HANDOFF.md` / `EXECUTION_STATE.json` were not updated in
  step;
- the command body mentions the staged handoff ID without also stating that it
  remains `NOT_EXECUTABLE` while `Executability change` is `none`.

## Transport

Brain commits the record directly when it has repository write access.
Otherwise Brain issues the instruction through Drive, a GitHub comment that
wakes the bridge, or an exceptional session relay. The Engineer then transcribes
it with the same meaning into the next free `CMD` file, sets
`Recorded by: Engineer (transcription)`, and cites the `Source`. Comment text on
its own is never a command.
