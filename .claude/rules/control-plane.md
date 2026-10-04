# Rule: control-plane files

- `docs/agent/commands/CMD-####.md` belong to Brain. Do not edit their meaning.
  If you transcribe a Brain instruction into a new `CMD`, set `Recorded by` to
  the Engineer and cite the source.
- `docs/agent/returns/RET-####.md` belong to the Engineer. After a return is
  pushed, do not rewrite it. Issue a new `RET` that supersedes it.
- Never reuse or renumber `LA-####`, `CMD-####`, `RET-####`, or `REUSE-####` IDs.
- Keep `EXECUTION_STATE.json` pointers (`last_command_id`,
  `last_acknowledged_command_id`, `last_return_id`, `command_ledger`) in step with
  the files on disk. Run the validator before every push.
- A staged `NOT_EXECUTABLE` handoff stays untouched until Brain PASS is recorded
  through the explicit executability-change path (AGENTS.md §13.5).
## Founder tooling-cost rule

- Do not recommend, introduce, or depend on paid third-party apps, paid SaaS, paid browser automation, wallet top-ups, or paid preview/hosting services unless the Founder explicitly asks for a paid option.
- Prefer free/open-source tooling, GitHub/Flutter capabilities already available to the project, and zero-cost preview/deployment paths.
- A paid-service limitation must not be presented as a reason to stop while a credible free path exists.

