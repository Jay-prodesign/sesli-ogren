# LA-0011 — Canonical model mapping and product-shell fit

- Task: [LA-0011](../../exec-plans/LA-0011.md) · Mission: CLAUDE_HANDOFF_001 · Date: 2026-09-29
- Semantic authority: V0_CANONICAL_DATA_CAPABILITY_CONTRACTS_v0.1 (Drive), including its D-034/D-037 overlays.
  Review 003 correction (CMD-0007…CMD-0013, 2026-09-30): speech is read through **D-062** (D-035/D-041/D-042 alone are
  not current speech authority), and product scope through CMD-0012/CMD-0013 (D-043, D-054). See §5–§7.
- Donor evidence: MoonlighC/ai-study-buddy@`317e21d`, whose schema was dumped from the 35/35 applied migrations (LA-0010).
- Result: the canonical schema is
  [`spike/architecture-proof/db/migrations/`](../../../spike/architecture-proof/db/migrations/).
  It has one authority per concept. The donor tables are **not** carried over; their mechanics are adapted.

## 1. Mapping table

| Canonical object | Spike authority | Donor source (MoonlighC) | Disposition | Notes |
| --- | --- | --- | --- | --- |
| IdentityAccount | `accounts` (PK = `auth.users.id`) | `profiles` | ADAPT | Created by trigger on `auth.users`. The donor profile's display fields are UI data and are deferred. Locale is kept separate (D-034). |
| Material | `materials` | `materials` (container part) | ADAPT + **split** | The container only: title, type, lifecycle, processing summary. |
| SourceAsset | `source_assets` | `materials.content_text / storage_* / mime_type / file_size_bytes` | **Split out** | First-class and versioned (`source_version`), hashed, revocable, with `knowledge_class` (D-033) and `trust_class` (D-036). |
| ExtractedContent | `extracted_contents` | `materials.content_text`, `material_processing_pages.normalized_text` | **Split out** | Derived from a SourceAsset. Carries method and version. Invalidated when the source is revoked. |
| Artifact (SUMMARY) | `artifacts` | `materials.summary / summary_payload / summary_*` | **Split out** | Persistent, versioned, lineage to job and attempt, `trust_class = AI_GENERATED`, supersession chain. **Material has no summary column** (test-enforced). |
| GenerationJob | `generation_jobs` | `material_processing_jobs` **and** `study_generation_operations` | ADAPT + **unify** | One job authority with the 7 canonical states. The donor's two operational systems collapse into it. |
| GenerationAttempt | `generation_attempts` | `material_processing_attempts` (+ `retry_authorizations`) | ADAPT | Keeps the donor `dispatch_state` / `budget_effect` / predecessor lineage. |
| EvidenceRef | `evidence_refs` | — (donor has none) | CUSTOM | Links an artifact to its source asset and extraction. |
| UsageEvent | `usage_events` | `usage_logs` | ADAPT | Idempotency key per job: one billable event per job. |
| QuotaLedger | `quota_ledger` | `daily_usage_limits` | ADAPT | Server-authoritative; checked in `request_summary`. |
| Entitlement | `entitlements` | `profiles.is_unlimited_tester` | ADAPT (seam only) | Plan, status, and limits. No payment integration (out of scope). |
| FeatureConfig | `feature_configs` | — | CUSTOM (seam only) | Read-only to clients. |
| LibraryItem | `library_items` **view** (security_invoker) | client-side list over `materials` | ADAPT | A projection with no stored truth. |
| FlashcardSet | not in spike schema | `flashcards` (per-card rows, no set) | ADAPT **later**, only if admitted | Candidate artifact type, not a required V0 surface (CMD-0013 / D-054). If admitted: a set/artifact parent and stable card IDs; the donor's SRS fields on cards become V1 debt. |
| Quiz / QuizAttempt | not in spike schema | `quizzes`, `quiz_questions`, `quiz_attempts` | ADAPT **later**, only if admitted | Candidate artifact type, not a required V0 surface (CMD-0013 / D-054). If admitted: `artifact_id` linkage must be added. |
| AudioAsset | not in spike schema | — | CUSTOM **later** | Sesli Öğren product-local speech output behind a replaceable Speech Capability boundary (D-062, §6). Not part of the voice-optional core. |
| LearnerEvidence / LearnerState (D-037) | not in spike schema | `quiz_attempts`, `study_sessions`, `weak_topics` | **MIGRATION_DEBT** (additive) | These donor tables are evidence *sources* only. `weak_topics` must not become mastery truth. Stable IDs are necessary attachment points, but they are **not** sufficient: the learner-loop authorities are missing and are itemised in §5. |

## 2. Rejected donor semantics

- **`public.materials` mega-object.** It combines the material container, source content,
  extracted text, and the summary result (`summary`, `summary_payload`, ...). It is split into four
  canonical tables. A `materials.summary` column would make the summary a mutable string on the container,
  which violates Artifact versioning and lineage.
- **Two generation authorities.** `material_processing_jobs/attempts` (PDF analysis) and
  `study_generation_operations` (flashcards/quiz) are unified into `generation_jobs` / `generation_attempts`.
  The donor's per-feature idempotency (`request_hash`) and reconciliation tokens become fields of the one job
  model: `request_fingerprint`, attempt `dispatch_state`, and reconciliation.
- **`subjects`.** A donor organizing concept that is not in the V0 canonical contract. It is deferred (a UX decision, not data truth).
- **`favorites`, `weak_topics`** stay out of the spike. `weak_topics` is explicitly not mastery state (D-037 firewall).
- **Client table writes.** The donor grants client insert/update on several tables. The canonical schema
  grants clients **SELECT only**. Every write goes through a SECURITY DEFINER RPC with explicit owner checks.

## 3. Migration/adapter plan implied (for LA-0016 burden)

- No dual writes. The donor schema is replaced, not synchronized. Existing donor data has no production
  users of ours, so there is no data migration.
- The donor Flutter repositories that read `materials.summary` or `StudyMaterial` must be re-pointed to
  `library_items` / `artifacts`. The file counts are measured in LA-0016.
- Donor RPCs for PDF page analysis (`material_analysis_*`, ~20 functions) map onto the canonical job model
  when PDF processing is admitted. That is V0 later work, not the spike.

## 4. Final Engineering Test — canonical split decision (D-029)

| # | Question | Answer |
| --- | --- | --- |
| 1 | Necessary now? | Yes. Acceptance criterion 1 (no parallel authorities) fails on the donor schema. |
| 2 | Simplest credible? | Yes: 12 tables, 1 view, 4 user RPCs, and 5 worker RPCs. There are no triggers beyond `updated_at` and account creation. |
| 3 | Secure by default? | Yes. RLS + FORCE RLS on every table, client SELECT-only, owner checks in every definer, non-revealing errors (tests 20). |
| 4 | Understandable? | Yes. One table per canonical concept, named after it. |
| 5 | Testable? | Yes. 4 SQL test files pass and 3 mutations are caught. |
| 6 | Observable on failure? | Yes. Job and attempt states, `failure_class`, `dispatch_state`, and `budget_effect` are queryable by the owner. |
| 7 | Replaceable/evolvable? | Yes. Artifact types, capability, and contract version are data. New artifact types extend CHECK constraints. |
| 8 | Privacy acceptable? | Yes. Source text stays in owner-only rows, and deletion revokes and invalidates derived rows. There are no analytics copies. |
| 9 | Operational cost reasonable? | Yes. Plain Postgres/Supabase with no new services. |
| 10 | Today without constraining tomorrow? | Yes. No destructive replacement or parallel truth is needed for the D-037 loop (§5). The learner-loop authorities themselves are additive migration debt, not modeled here. |

## 5. D-037 compatibility / debt map (Review 003 item B, CMD-0007)

Assessment only. Nothing below is implemented in M4, and no BKT, knowledge graph, RL policy, adaptive difficulty,
pass-probability model or FSRS is added. **FUTURE_COMPATIBLE** means the current schema already provides the anchor.
**MIGRATION_DEBT** means additive work is needed later. **BLOCKED** would mean the base cannot take it without replacement;
no row is BLOCKED.

| D-037 authority | Current anchor / proposed attachment point | Disposition | Additive work required later | Destructive replacement? | Parallel truth? |
| --- | --- | --- | --- | --- | --- |
| OutcomeContract | None first-class. Attaches to `accounts.id` (owner) and optionally `materials.id` (scope). | MIGRATION_DEBT | A new owner-scoped, versioned outcome table as the single outcome authority. | No | No, if it is the only outcome authority |
| Objective / CompetencyRef | None. Donor `subjects` / `weak_topics` are rejected as truth (§2). | MIGRATION_DEBT | An objective/competency reference model scoped to outcome, material or domain. | No | No |
| LearnerEvidence (append-only, versioned, idempotent, provenance-bearing) | None. `evidence_refs` are **source citations for generated artifacts** and must not be overloaded as learner evidence. The idempotency pattern (per-account key + unique index, as in `usage_events` / `generation_jobs`) is the template. | MIGRATION_DEBT | An append-only learner-event table: account owner, idempotency key, action/source/artifact provenance, occurred-at, schema version. Donor `quiz_attempts` / `study_sessions` feed it; they do not become it. | No | No |
| LearnerState (mastery/readiness separate from evidence confidence/coverage) | None. `weak_topics` is rejected as mastery truth. | MIGRATION_DEBT | A derived, versioned state record. Learning state and evidence confidence/coverage are separate fields. It is recomputable from evidence and never hand-edited. | No | No; derived, not a second store |
| LearningMission | None. | MIGRATION_DEBT | A mission record that references outcome, objective, state version and the NBA decision that produced it. | No | No |
| LearningAction | None. `generation_jobs` / `artifacts` record **generation operations**, not learner actions. | MIGRATION_DEBT | A learner action/event model for the admitted action set. Action types are not fixed here (CMD-0012 / CMD-0013). | No | No |
| Deterministic, versioned NBA policy + reason codes | `feature_configs` (`key`, `params`, `version`) is a generic versioned-config seam. There is no NBA authority. | MIGRATION_DEBT, with a FUTURE_COMPATIBLE attachment point | A deterministic policy/config version plus explicit reason codes, with the policy version recorded on each decision/mission. | No | No |
| Rule/config version + recompute/derivation lineage | `feature_configs.version`, stable account/material/artifact/job IDs, versioned artifacts (`version`, supersession), `extracted_contents.method_version`, `source_assets.source_version`, `artifacts.content_schema_version`. | FUTURE_COMPATIBLE substrate; learner-state lineage is MIGRATION_DEBT | Persist the rule version and the input evidence set (or an equivalent recompute key) on each derived state/decision. | No | No |
| Tenant ownership / RLS | `account_id` on every owner table, RLS + FORCE RLS, SELECT-only clients, SECURITY DEFINER owner checks, non-revealing errors (test 20). | FUTURE_COMPATIBLE | Every new learner-loop table inherits the same pattern and gets isolation tests. See also hardening debt H2 (LA-0016 §5). | No | No |
| Deletion / revocation | `delete_material` revokes sources and invalidates derived rows; `accounts` cascade from `auth.users` (test 20 §8). | FUTURE_COMPATIBLE for source-bound data; learner-loop semantics are MIGRATION_DEBT | Define how evidence, state and missions react to source revocation, material deletion and account deletion, so that no derived recommendation survives inaccessible sources. | No | No |
| Provenance / trust lineage | `source_assets.knowledge_class` / `trust_class`, `artifacts.trust_class = AI_GENERATED`, `evidence_refs`, versioned extraction → artifact chain. | FUTURE_COMPATIBLE | Learner evidence records action/source/generated-context provenance. Derived state and NBA keep evidence lineage and rule version. | No | No |
| Links to Material / SourceAsset / Artifact / Job / Attempt | Stable UUID primary keys on all five, owner-scoped. | FUTURE_COMPATIBLE | Foreign keys from new learner-loop tables. | No | No |

**Conclusion.** The Architecture Proof is D-037 **compatible**: no destructive replacement and no unavoidable
parallel truth is needed. It is **not** correct to say the D-037 loop is modeled. The missing learner-loop
authorities are explicit additive migration debt, to be admitted after M4. The earlier statement in this document
("stable IDs preserve compatibility") was over-broad and is corrected above.

## 6. Language, speech and evaluation compatibility (CMD-0004 → CMD-0013, D-062)

- **Language semantics (D-034).** The distinct meanings stay representable and nothing collapses them.
  - uiLocale ≈ `accounts.locale` (default `tr-TR`, BCP-47 checked).
  - contentLocale / learningLocale = the generation contract's `outputLocale`, echoed in the artifact's `language`.
  - sourceLocale and voiceLocale have no column yet.

  Debt: persist the requested output locale on `generation_jobs` (the harness worker currently defaults to `tr-TR`),
  and add `source_assets.source_locale` and a voice locale when admitted. Both are additive nullable columns.
  Turkish-first; no English UI.
- **Voice-optional core (D-042, CMD-0011/0012/0013).** No canonical table, RPC or learner-loop anchor depends on speech.
  Speech output would attach as a product-local AudioAsset/artifact type produced by the same job model.
- **Speech (D-062).** Speech is product-local to Sesli Öğren, and no shared Speech Service is required. Before
  production provider lock-in, Sesli Öğren needs a stable, replaceable **Speech Capability boundary** so that no
  learner-domain, session or UI code depends on vendor SDK objects, voice IDs, credentials or error semantics.
  This is the same pattern that LA-0012 proves for structured generation. M4 implements no speech.
- **Evaluation readiness.** Deterministic fakes, typed output validation (`la_valid_summary_content`) and versioned
  artifacts/prompts give a replaceable attachment point for eval datasets and runners. No eval framework is added.

## 7. Product-scope note (CMD-0012 / CMD-0013)

This mapping does not encode any product hierarchy (map, companion, missions UI, READ/TEACH/CHECK, or the old
Summary/Flashcards/Quiz/Audio grid) as a V0 requirement. The SUMMARY artifact remains valid **proof** evidence for the
Material → job → artifact → library chain; it is not a claim about which V0 surfaces exist.
