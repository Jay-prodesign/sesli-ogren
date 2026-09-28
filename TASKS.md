# TASKS — Sesli Öğren (Learning App)

Hierarchy: **Milestone → Sprint → Section → Task**. Task IDs are `LA-####`,
stable and never reused. Rules: [`AGENTS.md` §10](AGENTS.md#10-task-map-rules-tasksmd).
Structure is enforced by `scripts/validate_bootstrap.py`.

This file is the **execution map** only. It is not product canonical truth (that
is Drive) and not the mutable cursor (Drive `CURRENT_EXECUTION_STATE`, projected
into [`docs/agent/EXECUTION_STATE.json`](docs/agent/EXECUTION_STATE.json)).
Planning uses progressive detail. Only the active milestone is decomposed to
tasks. Future milestones are skeletons whose sprints carry no tasks and no exec
plans until Brain admits them.

Status legend: `PLANNED` · `NOT_EXECUTABLE` · `READY` · `IN_PROGRESS` · `BLOCKED` ·
`CHANGES_REQUIRED` · `AWAITING_BRAIN_REVIEW` · `DONE` · `CANCELLED`
(only Brain sets `DONE`).
Milestone status: `ACTIVE` · `PLANNED / NOT_EXECUTABLE` · `DONE`.

Milestone numbering follows the program sequence in
*PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0* (M0 = bootstrap,
M1 = Architecture Proof, …). Drive lifecycle-stage labels use a different
numbering: lifecycle "M3" is this M0, and lifecycle "M4" is this M1.

Next unallocated ID: **LA-0009**.

---

## Milestone M0 — Repository & Agent Bootstrap

- Status: ACTIVE
- Handoff: CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap
- Branch: `chore/repository-bootstrap`
- Draft PR: [#1](https://github.com/Jay-prodesign/sesli-ogren/pull/1): Brain Review 001 = CHANGES_REQUIRED; corrections re-returned for Brain review (CMD-0001 → RET-0001)
- Exit gate: Brain BOOTSTRAP_PASS on the bootstrap draft PR.

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
- Verification: `AGENTS.md` covers all required sections incl. §12 D-024 reuse classes and §13 command bus; `CLAUDE.md` imports `@AGENTS.md` and states the mandatory read order incl. unread commands; `.claude/rules/` minimal; validator content checks pass.
- Exec plan: [docs/exec-plans/LA-0003.md](docs/exec-plans/LA-0003.md)

#### Section M0.S1.C — Planning and control plane

##### LA-0004 — Task map and execution plans

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0003
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Validator TASKS structure check passes (hierarchy, unique IDs, required fields, plan pointers resolve, full plan contract sections, whole-V0 skeleton M1…M7 PLANNED / NOT_EXECUTABLE).
- Exec plan: [docs/exec-plans/LA-0004.md](docs/exec-plans/LA-0004.md)

##### LA-0005 — Agent control files and documentation skeleton

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0003, LA-0004
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `docs/agent/*` present and `EXECUTION_STATE.json` parses with required keys; `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md` template present with all D-024 fields; `docs/architecture`, `docs/adr`, `docs/provenance`, `docs/qa` tracked via README files.
- Exec plan: [docs/exec-plans/LA-0005.md](docs/exec-plans/LA-0005.md)

#### Section M0.S1.D — Validation and delivery

##### LA-0006 — Bootstrap validation script and CI workflow

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0002, LA-0003, LA-0004, LA-0005
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `python3 scripts/validate_bootstrap.py` exits 0 and `python3 scripts/test_validate_bootstrap.py` passes locally; `bootstrap-validation` workflow passes on the draft PR head.
- Exec plan: [docs/exec-plans/LA-0006.md](docs/exec-plans/LA-0006.md)

##### LA-0007 — Draft PR delivery and state/evidence reconciliation

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0006, LA-0008
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Unmerged draft PR #1 against `main`; `EXECUTION_STATE.json` = `AWAITING_BRAIN_REVIEW` with repo/branch/base/head/PR and command pointers recorded; `ENGINEER_RETURN.md` and RET-0001 complete; control files mutually consistent.
- Exec plan: [docs/exec-plans/LA-0007.md](docs/exec-plans/LA-0007.md)

### Sprint M0.S2 — Bootstrap correction (Brain Review 001 / D-026)

#### Section M0.S2.A — Command bus and invocation bridge

##### LA-0008 — Brain↔Engineer Command Bus & Automated Claude Invocation Bridge

- Status: AWAITING_BRAIN_REVIEW
- Depends on: LA-0005, LA-0006
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `docs/agent/commands/` + `docs/agent/returns/` conventions exist; CMD-0001 answered by RET-0001; `EXECUTION_STATE.json` command pointers reconcile; validator CMD/RET and executability-guard checks plus negative tests pass; `.github/workflows/claude-bridge.yml` present and inert; bridge status recorded as `AUTO_AGENT_BRIDGE_BLOCKED` with exact gates.
- Exec plan: [docs/exec-plans/LA-0008.md](docs/exec-plans/LA-0008.md)

---

## Milestone M1 — Architecture Proof

- Status: PLANNED / NOT_EXECUTABLE
- Handoff: CLAUDE_HANDOFF_001 — V0 Architecture Spike (staged, **NOT_EXECUTABLE**)
- Entry gate: Brain BOOTSTRAP_PASS on M0 and explicit admission of CLAUDE_HANDOFF_001.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive); D-015, D-024, D-025
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M1.S1 — Donor fresh-audit & layered reuse matrix

- Status: PLANNED / NOT_EXECUTABLE
- Intent: fresh licence/provenance/source audit of approved donors; D-025 capability-by-capability reuse classification.

### Sprint M1.S2 — Bounded proof

- Status: PLANNED / NOT_EXECUTABLE
- Intent: canonical-model mapping, auth/tenant isolation, one material→artifact path, GenerationJob idempotency, provider-neutral seams, provenance; measured adaptation burden.

### Sprint M1.S3 — Spike return & selector outcome

- Status: PLANNED / NOT_EXECUTABLE
- Intent: evidence return; Brain disposition GO_ADAPT or FALLBACK_CLEAN_FLUTTER.

## Milestone M2 — VS-001 Golden Vertical Slice

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: Brain accepts the M1 selector outcome and admits VS-001.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive)
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M2.S1 — Slice foundation

- Status: PLANNED / NOT_EXECUTABLE
- Intent: admitted client/backend skeleton, auth, persistence and CI toolchain for the selected path.

### Sprint M2.S2 — Core material journey

- Status: PLANNED / NOT_EXECUTABLE
- Intent: Auth → PDF/Text → Processing → Material Workspace → Summary.

### Sprint M2.S3 — Library, reopen & slice hardening

- Status: PLANNED / NOT_EXECUTABLE
- Intent: Library → Reopen with persistence, retry, analytics and security boundaries; slice-level QA.

## Milestone M3 — V0 Implementation Tranches

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: Brain accepts VS-001 and admits each tranche separately.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive)
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M3.S1 — Learning artifacts tranche

- Status: PLANNED / NOT_EXECUTABLE
- Intent: Key Concepts, Flashcards, Quiz as persistent artifacts.

### Sprint M3.S2 — Audio & reading tranche

- Status: PLANNED / NOT_EXECUTABLE
- Intent: Audio/Listen and Reader where required.

### Sprint M3.S3 — Account, entitlements & monetization tranche

- Status: PLANNED / NOT_EXECUTABLE
- Intent: account/settings/privacy, quotas/entitlements, monetization seams.

### Sprint M3.S4 — Operations & polish tranche

- Status: PLANNED / NOT_EXECUTABLE
- Intent: analytics/operations, support, accessibility, product polish.

## Milestone M4 — Beta / Validation

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: Feature-complete V0 accepted by Brain; beta thresholds frozen.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive)
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M4.S1 — Beta readiness

- Status: PLANNED / NOT_EXECUTABLE
- Intent: instrumentation, quality/latency/cost/retention thresholds, beta cohort plan.

### Sprint M4.S2 — Real-user beta & evidence review

- Status: PLANNED / NOT_EXECUTABLE
- Intent: real users/devices/networks; AI output quality, activation, repeat use, unit economics, failure classes.

## Milestone M5 — Brand/Name Freeze & Release Readiness

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: Beta evidence accepted; Founder brand/name freeze.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive); D-022
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M5.S1 — Identity & store asset freeze

- Status: PLANNED / NOT_EXECUTABLE
- Intent: consumer name/identity, store assets and copy, localization.

### Sprint M5.S2 — Release gates

- Status: PLANNED / NOT_EXECUTABLE
- Intent: policies, deletion, restore behaviour, permissions, security/dependency checks, analytics/crash validation, final regression, operational rollback.

## Milestone M6 — Controlled Public V0 Release

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: All release gates pass and Founder authorizes release (protected action).
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive)
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M6.S1 — Staged release & monitoring

- Status: PLANNED / NOT_EXECUTABLE
- Intent: controlled rollout; crash/error/cost/support monitoring; rollback and feature-flag readiness.

## Milestone M7 — Post-Launch Learning / V1 Admission

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: V0 publicly released.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive); D-009
- Tasks: none allocated (progressive detail; allocated only on Brain admission)

### Sprint M7.S1 — Post-launch evidence review

- Status: PLANNED / NOT_EXECUTABLE
- Intent: usage, quality, cost and support evidence consolidated for Brain.

### Sprint M7.S2 — V0.x corrections or V1 admission

- Status: PLANNED / NOT_EXECUTABLE
- Intent: Brain/Founder decide V0.x priorities or admit V1 Personal Learning Engine; V1 is not automatic.
