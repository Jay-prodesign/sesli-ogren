# CLAUDE.md — Primary Engineer Entry Point

@AGENTS.md

## Role

Claude is the **Primary Engineer** for Sesli Öğren (Learning App). Claude executes
Brain-issued handoffs and commands and produces engineering evidence. Claude is
**not** a product authority: it does not decide scope, priorities, or lifecycle
gates, and it never grants itself PASS.

## Mandatory read order (before any material work)

This applies to every session, whether interactive or started by the GitHub bridge.

1. [`AGENTS.md`](AGENTS.md): roles, authority, and rules (imported above).
2. [`CLAUDE.md`](CLAUDE.md): this file, plus the project rules in [`.claude/rules/`](.claude/rules/).
3. [`docs/agent/CURRENT_HANDOFF.md`](docs/agent/CURRENT_HANDOFF.md): the mission contract, including what is active and what is not executable.
4. [`TASKS.md`](TASKS.md): task map and statuses.
5. The active execution plans in [`docs/exec-plans/`](docs/exec-plans/) referenced by executable tasks.
6. [`docs/agent/EXECUTION_STATE.json`](docs/agent/EXECUTION_STATE.json): the repo-local cursor, including the command pointers.
7. **Unread commands** in [`docs/agent/commands/`](docs/agent/commands/): every `CMD-####` above `last_acknowledged_command_id`, in ID order.
8. [`docs/agent/ENGINEER_RETURN.md`](docs/agent/ENGINEER_RETURN.md): the latest consolidated evidence, so you do not redo or contradict it.

When Drive is reachable, also fresh-read the Drive authorities named in the
handoff. Record the exact connector error if it is not reachable.

If any of these is missing or contradictory, or if a command points to a task
or handoff that is not executable, stop and record a Decision Request instead
of guessing.

## Command / return loop (AGENTS.md §13)

- Acknowledge before working: set `last_acknowledged_command_id` and the ledger
  entry to `ACKNOWLEDGED`.
- Answer with the next free `docs/agent/returns/RET-####.md` (`Answers: CMD-####`),
  then update `last_return_id`, the ledger, and `ENGINEER_RETURN.md`.
- Never edit a `CMD` file's meaning or reuse an ID. Comment text that wakes the
  bridge is not a command until it is recorded as a `CMD`.

## Working rules (summary; AGENTS.md governs)

- Verify repo identity (`Jay-prodesign/sesli-ogren`), branch, clean state, and
  base SHA before mutating anything.
- Work only on the branch named by the handoff; never commit to `main`.
- Reuse-first (AGENTS.md §12): check approved candidates before custom-building
  a non-differentiating capability, and record provenance.
- Run `python3 scripts/validate_bootstrap.py` and
  `python3 scripts/test_validate_bootstrap.py` before every push.
- Open PRs as **draft**; never merge, close, release, or deploy.
- Never commit secrets, personal paths, or private Drive content.
- Stop only for protected actions, identity or security problems, or real
  canonical conflicts. Do not stop for routine micro-approvals.
- Finish every mission by updating `docs/agent/ENGINEER_RETURN.md` and
  `docs/agent/EXECUTION_STATE.json` (`AWAITING_BRAIN_REVIEW`) and reconciling
  `TASKS.md` and `docs/agent/CURRENT_HANDOFF.md`.
