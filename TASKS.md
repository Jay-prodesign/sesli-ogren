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

Next unallocated ID: **LA-0029**.

---

## Milestone M0 — Repository & Agent Bootstrap

- Status: DONE
- Handoff: CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap
- Branch: `chore/repository-bootstrap`
- Draft PR: [#1](https://github.com/Jay-prodesign/sesli-ogren/pull/1): BOOTSTRAP_PASS at reviewed head `433c26c`; draft/unmerged, merge remains a Product Owner action
- Exit gate: Brain BOOTSTRAP_PASS — **met**.
- Cross-branch note: later Architecture Proof work used the reviewed bootstrap head; this branch does not duplicate those sibling-branch task files.

### Sprint M0.S1 — Bootstrap

#### Section M0.S1.A — Pre-flight and identity

##### LA-0001 — Pre-flight verification and canonical repository identity

- Status: DONE
- Depends on: none
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Recorded cwd/remote/branch/clean state/visibility/default branch/base SHA in `docs/agent/ENGINEER_RETURN.md`; Drive read attempt outcome recorded.
- Exec plan: [docs/exec-plans/LA-0001.md](docs/exec-plans/LA-0001.md)

#### Section M0.S1.B — Repository foundation

##### LA-0002 — Repository hygiene baseline

- Status: DONE
- Depends on: LA-0001
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `.gitignore`, `.editorconfig`, `.gitattributes`, `README.md` present; validator required-file check passes.
- Exec plan: [docs/exec-plans/LA-0002.md](docs/exec-plans/LA-0002.md)

##### LA-0003 — Agent operating contracts

- Status: DONE
- Depends on: LA-0001
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `AGENTS.md` covers all required sections incl. §12 D-024 reuse classes and §13 command bus; `CLAUDE.md` imports `@AGENTS.md` and states the mandatory read order incl. unread commands; `.claude/rules/` minimal; validator content checks pass.
- Exec plan: [docs/exec-plans/LA-0003.md](docs/exec-plans/LA-0003.md)

#### Section M0.S1.C — Planning and control plane

##### LA-0004 — Task map and execution plans

- Status: DONE
- Depends on: LA-0003
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Validator TASKS structure check passes (hierarchy, unique IDs, required fields, plan pointers resolve, full plan contract sections, whole-V0 skeleton M1…M7 PLANNED / NOT_EXECUTABLE).
- Exec plan: [docs/exec-plans/LA-0004.md](docs/exec-plans/LA-0004.md)

##### LA-0005 — Agent control files and documentation skeleton

- Status: DONE
- Depends on: LA-0003, LA-0004
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `docs/agent/*` present and `EXECUTION_STATE.json` parses with required keys; `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md` template present with all D-024 fields; `docs/architecture`, `docs/adr`, `docs/provenance`, `docs/qa` tracked via README files.
- Exec plan: [docs/exec-plans/LA-0005.md](docs/exec-plans/LA-0005.md)

#### Section M0.S1.D — Validation and delivery

##### LA-0006 — Bootstrap validation script and CI workflow

- Status: DONE
- Depends on: LA-0002, LA-0003, LA-0004, LA-0005
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `python3 scripts/validate_bootstrap.py` exits 0 and `python3 scripts/test_validate_bootstrap.py` passes locally; `bootstrap-validation` workflow passes on the draft PR head.
- Exec plan: [docs/exec-plans/LA-0006.md](docs/exec-plans/LA-0006.md)

##### LA-0007 — Draft PR delivery and state/evidence reconciliation

- Status: DONE
- Depends on: LA-0006, LA-0008
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: Unmerged draft PR #1 against `main`; `EXECUTION_STATE.json` = `AWAITING_BRAIN_REVIEW` with repo/branch/base/head/PR and command pointers recorded; `ENGINEER_RETURN.md` and RET-0001 complete; control files mutually consistent.
- Exec plan: [docs/exec-plans/LA-0007.md](docs/exec-plans/LA-0007.md)

### Sprint M0.S2 — Bootstrap correction (Brain Review 001 / D-026)

#### Section M0.S2.A — Command bus and invocation bridge

##### LA-0008 — Brain↔Engineer Command Bus & Automated Claude Invocation Bridge

- Status: DONE
- Depends on: LA-0005, LA-0006
- Owner: Brain
- Executor: Claude (Primary Engineer)
- Verification: `docs/agent/commands/` + `docs/agent/returns/` conventions exist; CMD-0001 answered by RET-0001; `EXECUTION_STATE.json` command pointers reconcile; validator CMD/RET and executability-guard checks plus negative tests pass; `.github/workflows/claude-bridge.yml` present and inert; bridge status recorded as `AUTO_AGENT_BRIDGE_BLOCKED` with exact gates.
- Exec plan: [docs/exec-plans/LA-0008.md](docs/exec-plans/LA-0008.md)

---

## Milestone M1 — Architecture Proof

- Status: DONE
- Handoff: CLAUDE_HANDOFF_001 — V0 Architecture Spike
- Entry gate: BOOTSTRAP_PASS + explicit admission — **met**.
- Exit gate: ARCHITECTURE_PROOF_PASS / GO_ADAPT — **met** at immutable reviewed head `0327d2e5b854df1c9923c65ed88f77151cfe9eed`.
- Evidence branch: `spike/v0-architecture-proof`, draft PR #2, unmerged. Detailed LA-0009…LA-0017 task/evidence files remain on that sibling stacked branch and are not duplicated into this Round 7 branch.
- Source: PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0 — Learning App (Drive); D-015, D-024, D-025
- Current branch implication: Architecture Proof is accepted, but M2/M5 feature implementation is still NOT_EXECUTABLE. Round 7 evidence work is a bounded pre-admission evidence program, not Golden Learning Slice implementation.

### Sprint M1.S1 — Donor fresh-audit & layered reuse matrix

- Status: PLANNED / NOT_EXECUTABLE
- Intent: fresh licence/provenance/source audit of approved donors; D-025 capability-by-capability reuse classification.

### Sprint M1.S2 — Bounded proof

- Status: PLANNED / NOT_EXECUTABLE
- Intent: canonical-model mapping, auth/tenant isolation, one material→artifact path, GenerationJob idempotency, provider-neutral seams, provenance; measured adaptation burden.

### Sprint M1.S3 — Spike return & selector outcome

- Status: PLANNED / NOT_EXECUTABLE
- Intent: evidence return; Brain disposition GO_ADAPT or FALLBACK_CLEAN_FLUTTER.

## Milestone M2 — VS-001 / M5 Golden Learning Slice

- Status: ACTIVE
- Handoff: CLAUDE_HANDOFF_002 — M5 Golden Learning Slice
- Branch: `feat/m5-golden-learning-slice`
- Entry gate: D-071 explicit Brain admission — **met** after M4 PASS, D-070 Founder Product/Visual PASS, Round 7 non-physical PASS and D-068 physical-device bounding.
- Acceptance authority: M5_GOLDEN_LEARNING_SLICE_ACCEPTANCE_CONTRACT_v0.1.
- Product authority: D-053/D-054 + V0_PRODUCT_SCOPE_v2.0; D/Knot is the only active Companion identity under D-070.
- Scope: one authenticated learner, real PDF or pasted text, authoritative source/version/provenance, grounded/versioned processing, one meaningful active learning action, durable LearnerEvidence, truthful minimal LearnerState, explainable next action, persistence/reopen/recovery.
- Boundary: physical device/mobile-readiness remains a later release blocker under D-068; routine GitHub Actions are OFF under D-072 and runtime/build evidence is batched at milestone/release; no deploy/release/paid-provider/credentials/V1 learner-model expansion.

### Sprint M2.S1 — Slice foundation

#### Section M2.S1.A — Production substrate and canonical persistence

##### LA-0018 — Integrate accepted architecture substrate into M5 production-shaped foundation

- Status: DONE
- Depends on: none
- Owner: Brain
- Executor: ChatGPT (temporary reversible engineering authority)
- Verification: accepted architecture proof substrate is available on the M5 branch without stale control-plane overwrite; canonical production-shaped domain/persistence boundary is defined for the admitted slice; bootstrap validator remains green.
- Exec plan: [docs/exec-plans/LA-0018.md](docs/exec-plans/LA-0018.md)

##### LA-0019 — Real material source authority, provenance and safe ingest

- Status: DONE
- Depends on: LA-0018
- Owner: Brain
- Executor: ChatGPT (temporary reversible engineering authority)
- Verification: PDF/plain-text source produces one authoritative Material/Source identity + immutable source version/provenance; retry cannot fork truth; deletion/supersession invalidation semantics are testable.
- Exec plan: [docs/exec-plans/LA-0019.md](docs/exec-plans/LA-0019.md)

### Sprint M2.S2 — Learning truth loop

#### Section M2.S2.A — Evidence, state and next action

##### LA-0020 — Active learning action → LearnerEvidence → LearnerState → next action

- Status: DONE
- Depends on: LA-0019
- Owner: Brain
- Executor: ChatGPT (temporary reversible engineering authority)
- Verification: at least one meaningful active action records durable canonical evidence; state derivation is deterministic/minimal; next action is explainable; passive consumption cannot create mastery/readiness.
- Exec plan: [docs/exec-plans/LA-0020.md](docs/exec-plans/LA-0020.md)

### Sprint M2.S3 — User-visible continuity and hardening

#### Section M2.S3.A — D/Knot app flow, reopen and recovery

##### LA-0021 — Production-shaped mobile flow with D/Knot, close/reopen and recovery

- Status: DONE
- Depends on: LA-0020
- Owner: Brain
- Executor: ChatGPT (temporary reversible engineering authority)
- Verification: the admitted slice is runnable as one coherent Flutter flow; D/Knot reflects learning state without owning truth; one continuity transition is exercised; close/reopen preserves source/action/evidence/state/next-action validity; stale/corrupt/retry paths fail closed or repair safely; applicable CI/security/accessibility checks pass.
- Exec plan: [docs/exec-plans/LA-0021.md](docs/exec-plans/LA-0021.md)



### Sprint M2.S4 — M5 checkpoint

#### Section M2.S4.A — Evidence, review and disposition

##### LA-0022 — M5 checkpoint evidence, independent review and disposition

- Status: IN_PROGRESS
- Depends on: LA-0021
- Owner: Brain
- Executor: ChatGPT (temporary reversible engineering authority)
- Verification: exact candidate head is frozen; applicable GLS matrix is reconciled; one bounded D-072 runtime/build batch is completed only after code freeze; dependency lock/reproducibility is closed; GLS-083 independent read-only review findings are resolved; Product/Learning/Creative/accessibility dispositions are explicit; remaining physical-device work stays bounded under D-068; Brain records PASS / CHANGES_REQUIRED / BLOCKED / OWNER_GATE.
- Exec plan: [docs/exec-plans/LA-0022.md](docs/exec-plans/LA-0022.md)

#### Section M2.S4.B — Project maturity / governance audit

##### LA-0023 — Project work maturity & depth audit

- Status: DONE
- Depends on: LA-0021
- Owner: Brain
- Executor: ChatGPT / Brain audit
- Verification: Drive `LA-0023 — PROJECT WORK MATURITY & DEPTH AUDIT — TASK SPEC + QUALITY GATE` records PASS WITH CHANGES REQUIRED, keeps LA-0022 as the active cursor, and projects only current-risk/hygiene remediation rather than reopening feature breadth.
- Exec plan: [docs/exec-plans/LA-0023.md](docs/exec-plans/LA-0023.md)

#### Section M2.S4.C — Post-M5 full-product admission

##### LA-0024 — Full-product shell + material continuity

- Status: DONE
- Depends on: LA-0022
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: D-077 development closure plus the post-M5 Tier-A premise audit admit the shortest user-visible path from real PDF/text intake through Home/Library, Material Workspace, grounded orientation, truthful progress/next-action, Recall and product-local Listen without adding a flat feature grid or unsupported mastery claims.
- Exec plan: [docs/exec-plans/LA-0024.md](docs/exec-plans/LA-0024.md)

##### LA-0025 — Grounded Teach / Explain

- Status: DONE
- Depends on: LA-0024
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: bounded checkpoint workflow `37377094721` passed strict format, Flutter analyze/test and PostgreSQL server migration/test coverage on `089038967b57748d784192f7869c2d51b35cabf9`.
- Exec plan: [docs/exec-plans/LA-0025.md](docs/exec-plans/LA-0025.md)

##### LA-0026 — Active Explain-Back

- Status: DONE
- Depends on: LA-0025
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: canonical D-054 EXPLAIN requirement is completed as a bounded source-bound learner explain-back → uncertainty-aware feedback → targeted repair/re-attempt → durable evidence loop; passive Explain remains evidence-neutral and no live/paid provider is authorized by this tranche.
- Exec plan: [docs/exec-plans/LA-0026.md](docs/exec-plans/LA-0026.md)

##### LA-0027 — Multi-material Library + selected-material continuity

- Status: DONE
- Depends on: LA-0026
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: multiple learner-owned materials coexist; Library opens the selected material; Recall/Listen/Explain remain explicitly bound to that material and cannot leak evidence/state across materials.
- Exec plan: [docs/exec-plans/LA-0027.md](docs/exec-plans/LA-0027.md)

##### LA-0028 — Bounded Focus Session

- Status: IN_PROGRESS
- Depends on: LA-0027
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: exact selected-source Focus session; bounded interaction; hint/direct-help escape hatch; fail-closed semantic feedback; no passive mastery evidence.
- Exec plan: [docs/exec-plans/LA-0028.md](docs/exec-plans/LA-0028.md)

## Milestone M3 — V0 Implementation Tranches

- Status: PLANNED / NOT_EXECUTABLE
- Entry gate: Brain accepts VS-001 and admits each tranche separately. Under D-074, a Product / Learning Premise Audit is required before the first major post-M5 product/learning tranche is admitted; exact audit task remains NOT_EXECUTABLE/unallocated until M5 closes.
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
