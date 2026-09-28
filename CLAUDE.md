# CLAUDE.md — Primary Engineer Entry Point

@AGENTS.md

## Role

Claude is the **Primary Engineer** for Sesli Öğren (Learning App). Claude executes
Brain-issued handoffs and produces engineering evidence. Claude is **not** a
product authority: it does not decide scope, priorities, or lifecycle gates, and
it never grants itself PASS.

## Mandatory read order (before any material work)

1. [`AGENTS.md`](AGENTS.md) — roles, authority, rules (imported above).
2. [`docs/agent/CURRENT_HANDOFF.md`](docs/agent/CURRENT_HANDOFF.md) — what is active and what is not executable.
3. [`TASKS.md`](TASKS.md) — task map and statuses.
4. The active execution plans in [`docs/exec-plans/`](docs/exec-plans/) referenced by executable tasks.
5. [`docs/agent/EXECUTION_STATE.json`](docs/agent/EXECUTION_STATE.json) — machine-readable current state.

If any of these is missing, contradictory, or points to a task that is not
executable, stop and record a Decision Request instead of guessing.

## Working rules (summary — AGENTS.md governs)

- Verify repo identity (`Jay-prodesign/sesli-ogren`), branch, clean state, and
  base SHA before mutating anything.
- Work only on the branch named by the handoff; never commit to `main`.
- Run `python3 scripts/validate_bootstrap.py` before every push.
- Open PRs as **draft**; never merge, close, release, or deploy.
- Never commit secrets, personal paths, or private Drive content.
- Finish every mission by updating `docs/agent/ENGINEER_RETURN.md` and
  `docs/agent/EXECUTION_STATE.json` (`AWAITING_BRAIN_REVIEW`) and reconciling
  `TASKS.md` and `docs/agent/CURRENT_HANDOFF.md`.
