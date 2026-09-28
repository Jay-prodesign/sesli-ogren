# CURRENT HANDOFF

Mission-level executable contract (Brain-owned, mirrored by the Engineer).
This file is **not** a message log. Incremental Brain instructions arrive as
[`commands/CMD-####.md`](commands/), and Engineer responses go to
[`returns/RET-####.md`](returns/) ([`README.md`](README.md)).

## Active

| Field | Value |
| --- | --- |
| Handoff | **CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap** |
| State | **ACTIVE**. Brain Review 001 = CHANGES_REQUIRED. Corrections delivered (CMD-0001 → RET-0001) and **AWAITING_BRAIN_REVIEW** |
| Executor | Claude (Primary Engineer) |
| Milestone | M0 — Repository & Agent Bootstrap (Drive lifecycle stage "M3") |
| Tasks | LA-0001 … LA-0008 (see [`TASKS.md`](../../TASKS.md)); LA-0008 = Brain↔Engineer Command Bus & Automated Claude Invocation Bridge (D-026) |
| Branch | `chore/repository-bootstrap` |
| Delivery | Existing unmerged **draft** PR against `main`: [#1](https://github.com/Jay-prodesign/sesli-ogren/pull/1) |
| Evidence | [`ENGINEER_RETURN.md`](ENGINEER_RETURN.md) (consolidated) · [`returns/RET-0001.md`](returns/RET-0001.md) |
| Exit gate | Brain **BOOTSTRAP_PASS** (or CHANGES_REQUIRED / BLOCKED), preferably issued as `CMD-0002` |

### Mission summary (non-private)

Bootstrap the repository's engineering governance: hygiene files, agent
contracts (including the D-024 reuse-first gate and the D-026 command bus), the
task map with the whole-V0 skeleton, complete execution contracts, agent control
files, the provenance register template, minimal `.claude/rules/`, lightweight
validation and CI, and an inert GitHub-triggered Claude wake-up bridge. No
application or product implementation. No merge, deploy, or release.

### Governing references (Drive, by title only)

- CURRENT_EXECUTION_STATE — Learning App
- CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap — Learning App
- M3_BOOTSTRAP_BRAIN_REVIEW_001 — CHANGES_REQUIRED — Learning App
- M3_REPOSITORY_BOOTSTRAP_ACCEPTANCE_CHECKLIST_v0.1 — Learning App
- DECISION_LOG — Learning App: D-019, D-020, D-023 (PUBLIC repository), D-024 (reuse-first), D-025 (layered donors), D-026 (command bus)
- PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App
- ENGINEERING_EXECUTION_PROTOCOL — Learning App
- PRODUCT_LIFECYCLE_STAGE_GATES — Learning App; V0_PRODUCT_SCOPE_v1.0 — Learning App (boundary only)

## Staged

| Field | Value |
| --- | --- |
| Handoff | **CLAUDE_HANDOFF_001 — V0 Architecture Spike** |
| State | **NOT_EXECUTABLE**. Staged pending Brain BOOTSTRAP_PASS on the CLAUDE_HANDOFF_000 draft PR |
| Rule | No agent may start any part of CLAUDE_HANDOFF_001 until Brain issues PASS and marks it executable here. A command must declare `Executability change` with PASS gate evidence and land together with this file and `EXECUTION_STATE.json` (AGENTS.md §13.5). |
