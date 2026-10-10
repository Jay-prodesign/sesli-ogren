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

Next unallocated ID: **LA-0041**.

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

- Status: CANCELLED
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

- Status: DONE
- Depends on: LA-0027
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: exact selected-source Focus session; bounded interaction; hint/direct-help escape hatch; fail-closed semantic feedback; no passive mastery evidence.
- Exec plan: [docs/exec-plans/LA-0028.md](docs/exec-plans/LA-0028.md)

##### LA-0029 — Truthful Progress Surface

- Status: DONE
- Depends on: LA-0028
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: learner-scoped canonical state only; no invented percentage/mastery; passive activity evidence-neutral; selected material can continue from Progress.
- Exec plan: [docs/exec-plans/LA-0029.md](docs/exec-plans/LA-0029.md)

##### LA-0030 — Durable Resume Continuity

- Status: DONE
- Depends on: LA-0029
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: Home selects the most recently updated active material; SQLite close/reopen preserves material plus canonical Recall state/next action; bounded workflow `37585838940` passed canonical format, Flutter analyze and expanded Flutter tests at head `377c9ce238883fced4e3a7fa99a29ecead91780f`.
- Exec plan: [docs/exec-plans/LA-0030.md](docs/exec-plans/LA-0030.md)

##### LA-0031 — Material deletion + safe continuity

- Status: DONE
- Depends on: LA-0030
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: Library exposes confirmed material deletion through the existing learner-scoped store semantics; deleting the most recent material removes accessible source/learning truth and Home safely falls back to the remaining material; bounded workflow `37585838940` passed canonical format, Flutter analyze and expanded Flutter tests at head `377c9ce238883fced4e3a7fa99a29ecead91780f`.
- Exec plan: [docs/exec-plans/LA-0031.md](docs/exec-plans/LA-0031.md)

##### LA-0032 — Durable Listen resume continuity

- Status: DONE
- Depends on: LA-0031
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: exact current SourceVersion owns the persisted Listen checkpoint; resume/restart controls remain evidence-neutral; v6→v7 additive migration and widget regression must pass strict format, Flutter analyze and bounded tests before DONE.
- Exec plan: [docs/exec-plans/LA-0032.md](docs/exec-plans/LA-0032.md)

##### LA-0033 — Profile + server-authoritative plan/usage surface

- Status: DONE
- Depends on: LA-0032
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: Profile reads only authenticated learner account/entitlement/quota truth; unavailable server truth fails closed; language/device-TTS/accessibility/privacy state is truthful; bootstrap run `37597120112` PASS and product-bounded-validation run `37597120046` PASS (format, analyze, expanded tests) on `a785783e54441ef5231e7b53c751d36fd408838f`.
- Exec plan: [docs/exec-plans/LA-0033.md](docs/exec-plans/LA-0033.md)

##### LA-0034 — Secure account + data deletion

- Status: DONE
- Depends on: LA-0033
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: authenticated deletion intent + server-only Storage/session/Auth cleanup; learner-scoped local purge; fail-closed destructive UI. Bootstrap run `37599984324` PASS, account-deletion bounded run `37599984408` PASS (PostgreSQL deletion slice + Deno lint/type-check), and product-bounded-validation run `37599984330` PASS (format, analyze, expanded Flutter tests) on `9010eed82eae067076629a1a1daca9d66486272b`. Hosted Supabase deployment remains intentionally deferred because the connected project has no canonical app schema/function deployment yet.
- Exec plan: [docs/exec-plans/LA-0034.md](docs/exec-plans/LA-0034.md)

##### LA-0035 — First-run product onboarding

- Status: DONE
- Depends on: LA-0034
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: first successful authenticated runtime shows a one-time onboarding before Product Shell; it explains material continuity, the passive-Listen vs active-learning evidence distinction, and implemented deletion control. Completion is learner-scoped in SQLite, survives reopen, is covered by additive v7→v8 migration, and is purged with learner data. Bootstrap run `37612556528` PASS, account-deletion run `37612556551` PASS, and product-bounded-validation run `37612556549` PASS (format, analyze, expanded tests) on `f1390330b6f0a1d522d18d60bbcaf32ef21df96f`.
- Exec plan: [docs/exec-plans/LA-0035.md](docs/exec-plans/LA-0035.md)


##### LA-0036 — Passwordless account entry + session restore

- Status: DONE
- Depends on: LA-0035
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: existing authenticated sessions restore without changing learner identity; no-session startup shows explicit passwordless email account entry instead of silently creating an anonymous user; successful OTP verification opens the verified learner runtime; missing Supabase client configuration fails closed. Bootstrap run `37614578993` PASS, account-deletion run `37614579001` PASS, and product-bounded-validation run `37614578893` PASS (format, analyze, expanded tests) on `00933dc76ab5190299adf563ca716c8b7310382b`. Live email delivery/template configuration remains deferred external release evidence.
- Exec plan: [docs/exec-plans/LA-0036.md](docs/exec-plans/LA-0036.md)

##### LA-0037 — Safe local sign-out + account switching boundary

- Status: DONE
- Depends on: LA-0036
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: confirmed local-session sign-out returns the root app to account entry only after Supabase sign-out succeeds; local learner data is preserved and remains learner-scoped; sign-out failure keeps the authenticated runtime open. Bootstrap run `37615873346` PASS, account-deletion run `37615873382` PASS, and product-bounded-validation run `37615873688` PASS (format, analyze, expanded tests) on `5496dc346451c49dd7b789cc67a0ebe40976665f`.
- Exec plan: [docs/exec-plans/LA-0037.md](docs/exec-plans/LA-0037.md)

##### LA-0038 — Truthful support contact surface

- Status: DONE
- Depends on: LA-0037
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: Profile exposes a release-configured client-safe support email when valid, allows copying it, and fails closed without inventing an address when configuration is absent/invalid. At head 5ee9f4fa8ab30504c7761ca5f5c6e7ae4fddc075: bootstrap-validation 37617623288 PASS, account-deletion-bounded-validation 37617623323 PASS, product-bounded-validation 37617623345 PASS. Actual production support address remains release configuration.
- Exec plan: [docs/exec-plans/LA-0038.md](docs/exec-plans/LA-0038.md)

##### LA-0039 — World-Class Experience / Golden Product Slice

- Status: IN_PROGRESS
- Tier: A — Founder-triggered product experience correction
- Depends on: LA-0038
- Owner: Brain
- Executor: ChatGPT (bounded reversible engineering)
- Verification: LA-0039 and LA-0040 are one integrated product outcome on PR #13. Engineering truth is SHA-specific; current implementation must preserve source/version/provenance, evidence semantics, error/recovery, persistence/reopen and navigation continuity while the visual direction is reworked. Founder visual disposition is required only to lock/close final visual direction, not to continue implementation.
- Intent: preserve the validated Golden Product Slice as an engineering baseline while LA-0040 reevaluates the visual system, student desirability and companion treatment. Learning truth, provenance/evidence semantics and current feature scope remain authoritative.
- Prior treatment: T2 Premium Active Learning Studio is now a baseline/control, not a locked final treatment.
- Quality authority: [docs/qa/LA-0039_WORLD_CLASS_EXPERIENCE_GATE.md](docs/qa/LA-0039_WORLD_CLASS_EXPERIENCE_GATE.md) + LA-0040 VQG-01.
- Current cursor: ACTIVE / COUPLED WITH LA-0040. Continue the coherent source → Reader/Listen → source-hidden Recall → truthful evidence/result → reasoned next action → reopen/resume outcome; do not wait on visual lock for independent product work.
- Exec plan: [docs/exec-plans/LA-0039.md](docs/exec-plans/LA-0039.md)

##### LA-0040 — Million-Dollar Visual Audit & Student Experience Elevation

- Status: IN_PROGRESS
- **LATEST FOUNDER OVERRIDE (second visual FAIL, 2026-10-08):** actual 12-screen Editorial/Studio/Knowledge treatment comparison is rejected as a whole; **NO Studio lead, NO accepted visual direction**. Stop incremental restyling of these controls. The active same-task scope is a product-local, source-centered interaction-first learning journey with real Flutter evidence, genuine Recall feedback, 320/390px and accessibility checks and explicit Founder visual acceptance. Consult [second-FAIL rework spec](docs/exec-plans/LA-0040_FOUNDER_FAIL_REWORK_SPEC.md), [QA gate](docs/qa/LA-0040_VISUAL_QUALITY_GATE.md), and [current handoff](docs/agent/CURRENT_HANDOFF.md). Existing CI PASS demonstrates technical functioning only, not UX quality.
- Gate: **FOUNDER VISUAL FAIL / CHANGES_REQUIRED (2026-10-08)** — prior VQG-01 PASS was internal pre-Founder evidence only; no Founder acceptance.
- Tier: A — Founder-triggered visual/product decision
- Depends on: LA-0039 engineering baseline
- Owner: Brain + Founder protected visual disposition
- Executor: Founder-authorized active product/engineering executor (ChatGPT/Claude/Codex when assigned); reversible implementation is executable now
- Verification: full-product visual packet and engineering gates are green at validated runtime head `93cd80be370e7a08f29358f175831a53bc474403`: bootstrap `37737380112` PASS, account-deletion `37737380121` PASS, product-bounded `37737380119` PASS (canonical format + Flutter analyze + bounded expanded tests). Final full visual capture `37737373695` PASS; artifact `11532626337` (`sha256:990e9494cef15d67b17fc5183ab50558cffe7818ab4cd7e13d138eb108eef748`) contains Home, Workspace, Recall prompt/payoff, Listen, Explain, Explain-Back, Focus, Library, Progress, Profile and narrow/text-scale stress evidence.
- Intent: validate a distinctive, premium, show-don't-tell Learning App experience without inventing learner state or discarding prior Learning App research.
- Audience: Sesli Öğren remains a broad learner-owned-material product; Turkish high-school students are the **priority-weighted initial commercial segment**, not the exclusive target.
- Previous candidate direction: **Living Visual Learning Studio / Student Momentum**. Historical internal VQG-01 = PASS, but **Founder rejected its actual runtime visual expression**. Current visual acceptance = FAIL / CHANGES_REQUIRED; design hierarchy, signature payoff, visual identity and Companion integration must be retested.
- Companion: **KEEP canonical D/Knot**. The generated non-canonical plush mascot is rejected; current evidence supports stateful/sparse integration, not identity redesign/removal.
- Palette/system: Cloud / Deep Focus / Pulse Blue / Signal Aqua / bounded Volt Lime is now **REOPENED AS A VISUAL TREATMENT HYPOTHESIS**, not a final accepted palette. Preserve semantic accessibility while comparing genuinely different runtime design treatments.
- Stress result: narrow Home + long Turkish title + 1.3× Workspace + 1.5× Recall captured without observed overflow/clip blocker; Reduced Motion remains separately covered.
- Founder disposition: **FAIL** on representative runtime visuals; do not label this merely "not PASS+". Internal capture/engineering PASS does not prove premium appeal. Real-user preference, memorability and future device QA remain separately unproven.
- Final VQG authority: [docs/qa/LA-0040_VQG_FINAL_PRE_FOUNDER_2026-10-08.md](docs/qa/LA-0040_VQG_FINAL_PRE_FOUNDER_2026-10-08.md).
- Quality gate: [docs/qa/LA-0040_VISUAL_QUALITY_GATE.md](docs/qa/LA-0040_VISUAL_QUALITY_GATE.md).
- Stress/red-team: [docs/qa/LA-0040_VISUAL_STRESS_REDTEAM.md](docs/qa/LA-0040_VISUAL_STRESS_REDTEAM.md).
- Round-1 retest: [docs/qa/LA-0040_VQG_ROUND1_RETEST_2026-10-08.md](docs/qa/LA-0040_VQG_ROUND1_RETEST_2026-10-08.md).
- Prior research/roadmap reconciliation: [docs/design/LA-0040_PRIOR_RESEARCH_ROADMAP_RECONCILIATION.md](docs/design/LA-0040_PRIOR_RESEARCH_ROADMAP_RECONCILIATION.md).
- Current cursor: **LA-0039_LA-0040_INTEGRATED_OUTCOME**. The three-treatment tournament is a failed historical experiment, not an active requirement. Build and refine ONE coherent source-centered real-Flutter learning journey, integrate truth/error/recovery/continuity/accessibility as needed, and keep moving to the next dependency-ready roadmap outcome. Founder approval is required only for final visual lock/closure.
- Exec plan: [docs/exec-plans/LA-0040.md](docs/exec-plans/LA-0040.md)


**Historical projection note:** The M3/M4/M5 skeletons below predate the
admitted/completed Golden Learning Slice and the current post-M5 LA-0039 +
LA-0040 outcome. Their `PLANNED / NOT_EXECUTABLE` labels are retained only to
preserve the validator-compatible whole-V0 map; they do not re-close work
already admitted by later canonical decisions and are not a competing live
cursor. Use Drive `CURRENT_EXECUTION_STATE` + `MASTER_ROADMAP` and the
LA-0039/LA-0040 entries above for live sequencing.

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
