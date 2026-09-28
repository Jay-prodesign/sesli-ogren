# TASKS — Sesli Öğren (Learning App)

Hierarchy: **Milestone → Sprint → Section → Task**. Task IDs are `LA-####`,
stable and never reused. Rules: [`AGENTS.md` §10](AGENTS.md#10-task-map-rules-tasksmd).
Structure is enforced by `scripts/validate_bootstrap.py`.

Status legend: `PLANNED` · `NOT_EXECUTABLE` · `READY` · `IN_PROGRESS` · `BLOCKED` ·
`CHANGES_REQUIRED` · `AWAITING_BRAIN_REVIEW` · `DONE` · `CANCELLED`
(only Brain sets `DONE`).
Milestone status: `ACTIVE` · `PLANNED / NOT_EXECUTABLE` · `DONE`.

Next unallocated ID: **LA-0008**.

---

## Milestone M0 — Repository & Agent Bootstrap

- Status: ACTIVE
- Handoff: CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap
- Branch: `chore/repository-bootstrap`
- Draft PR: [#1](https://github.com/Jay-prodesign/sesli-ogren/pull/1) — awaiting Brain review
- Exit gate: Brain PASS on the bootstrap draft PR.

### Sprint M0.S1 — Bootstrap

#### Section M0.S1.A — Pre-flight and identity

##### LA-0001 — Pre-flight verification and canonical repository identity

- Status: AWAITING_BRAIN_REVIEW
- Depends on: none
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Recorded cwd/remote/branch/clean state/visibility/default branch/base SHA in `docs/agent/ENGINEER_RETURN.md`; Drive read attempt outcome recorded.
- Exec plan: [docs/exec-plans/LA-0001.md](docs/exec-plans/LA-0001.md)

#### Section M0.S1.B — Repository foundation

##### LA-0002 — Repository hygiene baseline

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0001
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `.gitignore`, `.editorconfig`, `.gitattributes`, `README.md` present; validator required-file check passes.
- Exec plan: [docs/exec-plans/LA-0002.md](docs/exec-plans/LA-0002.md)

##### LA-0003 — Agent operating contracts

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0001
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `AGENTS.md` covers all required sections; `CLAUDE.md` imports `@AGENTS.md` and states the mandatory read order; validator content checks pass.
- Exec plan: [docs/exec-plans/LA-0003.md](docs/exec-plans/LA-0003.md)

#### Section M0.S1.C — Planning and control plane

##### LA-0004 — Task map and execution plans

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0003
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Validator TASKS structure check passes (hierarchy, unique IDs, required fields, plan pointers resolve).
- Exec plan: [docs/exec-plans/LA-0004.md](docs/exec-plans/LA-0004.md)

##### LA-0005 — Agent control files and documentation skeleton

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0003, LA-0004
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `docs/agent/*` present and `EXECUTION_STATE.json` parses with required keys; `docs/architecture`, `docs/adr`, `docs/provenance`, `docs/qa` tracked via README files.
- Exec plan: [docs/exec-plans/LA-0005.md](docs/exec-plans/LA-0005.md)

#### Section M0.S1.D — Validation and delivery

##### LA-0006 — Bootstrap validation script and CI workflow

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0002, LA-0003, LA-0004, LA-0005
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `python3 scripts/validate_bootstrap.py` exits 0 locally; `bootstrap-validation` workflow passes on the draft PR.
- Exec plan: [docs/exec-plans/LA-0006.md](docs/exec-plans/LA-0006.md)

##### LA-0007 — Draft PR delivery and state/evidence reconciliation

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0006
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Unmerged draft PR against `main` exists; `EXECUTION_STATE.json` = `AWAITING_BRAIN_REVIEW` with repo/branch/base/head/PR recorded; `ENGINEER_RETURN.md` complete; control files mutually consistent.
- Exec plan: [docs/exec-plans/LA-0007.md](docs/exec-plans/LA-0007.md)

---

## Milestone M1 — V0 (first product milestone)

- Status: PLANNED / NOT_EXECUTABLE
- Handoff: CLAUDE_HANDOFF_001 (staged, NOT_EXECUTABLE pending Brain review of M0)
- Scope: defined by Brain from the V0 product scope in the Drive governance set. Not transcribed here.
- Sprints / sections / tasks: none allocated.

## Milestone M2+ — Later V0 milestones

- Status: PLANNED / NOT_EXECUTABLE
- Scope: to be defined by Brain. No tasks allocated.
