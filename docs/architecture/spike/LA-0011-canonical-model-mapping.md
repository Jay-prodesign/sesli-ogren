# LA-0011 — Canonical model mapping and product-shell fit

- Task: [LA-0011](../../exec-plans/LA-0011.md) · Mission: CLAUDE_HANDOFF_001 · Date: 2026-09-29
- Semantic authority: V0_CANONICAL_DATA_CAPABILITY_CONTRACTS_v0.1 (Drive), including its D-034/D-035/D-037 overlays.
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
| FlashcardSet | not in spike schema | `flashcards` (per-card rows, no set) | ADAPT **later** (V0L) | Needs a set/artifact parent and stable card IDs. The donor stores SRS fields on cards, which becomes V1 debt. |
| Quiz / QuizAttempt | not in spike schema | `quizzes`, `quiz_questions`, `quiz_attempts` | ADAPT **later** (V0L) | The shapes are close. `artifact_id` linkage must be added. |
| AudioAsset | not in spike schema | — | CUSTOM **later** | D-035: concrete-first, no shared speech seam. |
| LearnerEvidence / LearnerState (D-037) | not in spike schema | `quiz_attempts`, `study_sessions`, `weak_topics` | Mapping finding only | These donor tables are evidence *sources*. `weak_topics` must not become mastery truth. Compatibility is preserved because artifacts, jobs, and accounts carry stable IDs that evidence can reference. |

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
| 10 | Today without constraining tomorrow? | Yes. Stable IDs let D-037 learner evidence reference artifacts and jobs later without reshaping these tables. |
