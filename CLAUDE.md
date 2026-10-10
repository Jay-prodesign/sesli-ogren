# CLAUDE.md — Primary Engineer Entry Point

@AGENTS.md

## Role

Claude remains the repository's historical **Primary Engineer** role label, but
under the current continuous-outcome authority it is an **available implementation
executor**, not a mandatory waiting dependency. When the live cursor assigns or
admits Claude, Claude may carry reversible in-scope product work through
implementation, integration, proportional verification, repair, and the next
dependency-ready outcome. Claude is not product authority and cannot self-authorize
protected actions.

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

If a material canonical contradiction remains after applying the current-state
and supersession rules, isolate only the affected dependency and record a
Decision Request. Continue independent admitted work; do not treat historical
handoff/cursor text as a global stop.

## Command / return loop (AGENTS.md §13)

The command/return bus is used only when Claude is explicitly launched through
that delegation path. It remains auditable and its IDs are never rewritten, but
routine product execution does not require a CMD/RET round trip, an
`AWAITING_BRAIN_REVIEW` transition, or a PASS before continuing to the next
safe in-scope outcome.

When a live CMD explicitly governs the session, acknowledge and answer it using
the existing ledger/return conventions without turning each implementation
substep into a separate command.

## Working rules (summary; AGENTS.md governs)

- Verify repo identity (`Jay-prodesign/sesli-ogren`), branch, clean state, and
  base SHA before mutating anything.
- Work only on the branch named by the handoff; never commit to `main`.
- Reuse-first (AGENTS.md §12): check approved candidates before custom-building
  a non-differentiating capability, and record provenance.
- Use risk-proportional validation. Run control-plane validators when control
  files change and grouped Flutter/product checks at coherent milestones; do not
  run a full matrix for every cosmetic or local change.
- Open PRs as **draft**; never merge, close, release, or deploy.
- Never commit secrets, personal paths, or private Drive content.
- Stop only for protected actions, identity or security problems, or real
  canonical conflicts. Do not stop for routine micro-approvals.
- Keep the single live cursor coherent at meaningful checkpoints. Routine
  outcomes remain `IN_PROGRESS` and flow directly into the next admitted
  outcome; use `AWAITING_BRAIN_REVIEW` only when a real current checkpoint
  explicitly requires that review.
