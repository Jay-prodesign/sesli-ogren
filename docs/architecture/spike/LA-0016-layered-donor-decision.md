# LA-0016 — Layered donor/dependency decision and adaptation-burden measurement

- Task: [LA-0016](../../exec-plans/LA-0016.md) · Mission: CLAUDE_HANDOFF_001 · Date: 2026-09-29
- Inputs: LA-0010 audit, LA-0011 mapping, LA-0012 seam, LA-0013–0015 proofs. All counts come from commands run on
  MoonlighC/ai-study-buddy@`317e21d` and on this branch.

## 1. Capability reuse matrix (D-025)

Scope: **RS** REQUIRED_FOR_SPIKE · **V0L** V0_CANDIDATE_LATER · **V1** V1_OR_LATER_DEFERRED.
Every MoonlighC reference below is `MoonlighC/ai-study-buddy@317e21df…`, MIT (notice: `docs/provenance/licenses/`).

| Capability | Scope | Selected path | Reuse class | Integration surface | Canonical mapping | Tests to keep/add | Burden | Why not the more mature alternative |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Auth / account lifecycle | RS | Supabase Auth + MoonlighC auth repository | ADAPT | `auth.users` → `accounts` trigger; donor `lib/features/auth/*` | IdentityAccount | Donor auth widget tests (in 633 green); canonical account-trigger test (10) | Low: donor auth reads `profiles`, re-point to `accounts` | Nibomo auth (Cognito/Hono) would replace the Supabase stack, so PATTERN-ONLY |
| Tenancy / RLS / isolation | RS | Canonical RLS adapted from MoonlighC 001/008 | ADAPT (REUSE-0002) | 12 tables, FORCE RLS, SELECT-only clients | all owner-scoped objects | `20_tenant_isolation.sql` (44 checks) | Done in spike | Open Notebook has single-password access, so it is not a tenancy model |
| Material upload / storage / lifecycle | RS (storage policy) · V0L (upload UI) | MoonlighC storage policies + upload queue | ADAPT | `storage.objects` policies (spike); donor `material_upload_*` (later) | SourceAsset storage ref | Storage cases in test 20; donor upload tests later | Medium: the upload flow must create a `source_assets` row instead of `materials.storage_*` | — |
| Parsing / OCR / chunking | V0L | MoonlighC `extract-pdf-text` (unpdf), OCR adapters | ADAPT later | Deno functions → `extracted_contents` | ExtractedContent | Donor Deno tests (20+6+2 green) | Medium: 3 functions write legacy columns | Docling (Python) would add a runtime: PATTERN-ONLY. NotebookLM-Lite `ChunkingService`: PATTERN-ONLY |
| Retrieval / citations | V0L | CUSTOM behind the EvidenceRef contract | PATTERN-ONLY (Open Notebook, NotebookLM-Lite) | `evidence_refs` (whole-source anchor in spike) | EvidenceRef | Later | — | Python/SurrealDB stacks. The interface ideas are reused, the code is not |
| Summary / artifact generation | RS | Canonical job + Deno seam; donor summary prompt/validation as reference | ADAPT (mechanics) + CUSTOM (seam) | `generation_jobs/attempts`, `artifacts`, worker | Artifact, GenerationJob/Attempt | 10, 11, 30 + Deno 13 | Done in spike | Donor `openai_adapter.ts` is OpenAI-specific, so it is replaced by the contract |
| Flashcards / quizzes | V0L, only if admitted (CMD-0013 / D-054) | MoonlighC `generate-flashcards/quiz` + tables | ADAPT later | New artifact types on the same job model | FlashcardSet, Quiz | Donor Deno 11+12 green; canonical tests later | Medium: add an artifact parent and stable IDs; SRS fields off cards | OpenTutor learning-science patterns only where the V0 contract requires them |
| Job / retry / idempotency | RS | Canonical unified job model adapted from MoonlighC 010 | ADAPT (REUSE-0002) | 5 worker RPCs, lease tokens, dispatch_state | GenerationJob/Attempt, UsageEvent | 30 (33 checks) + Deno integration | Done in spike | — |
| Provider routing | RS | Learning App contract + fetch adapter | CUSTOM (seam); `vercel/ai` DEPENDENCY candidate, not adopted | `functions/_shared/generation/*` | StructuredGenerationCapability | Deno 8 seam tests | Done in spike | SDK: 94× bundle, 11 packages, Gateway pulled in (LA-0012). Esperanto: Python. LiteLLM: licence scope unreviewed |
| Audio / TTS / speech | V0L (Sesli Öğren composition) | Product-local Speech Capability behind a replaceable boundary (D-062). The core stays voice-optional (D-042) | PATTERN-ONLY (Open Notebook) | Job-produced artifact through the same job model | AudioAsset | Later | Medium: provider benchmark + boundary before lock-in | No shared Speech Service before proven reuse (D-062). Provider choice is measured Turkish-first, not preference |
| Study-session persistence | V0L | MoonlighC migration 026 | ADAPT later | `study_sessions` → learner evidence (D-037) | LearnerEvidence | Donor SQL test 26 (passes at its own step only) | Medium | — |
| Spaced repetition | V1 (engine) | `open-spaced-repetition/dart-fsrs` when admitted | DEFERRED | — | FlashcardReviewState | — | — | V0 does not admit SRS; Nibomo `ts-fsrs` and OpenTutor are references |
| Progress / mastery | V0L (progress) · V1 (mastery) | MoonlighC 027 progress; D-037 rule-based state later | ADAPT later / PATTERN-ONLY (OpenTutor BKT/KG) | — | LearnerState (D-037) | — | Medium | V1 firewall; `weak_topics` must not become mastery truth |
| Offline / sync | V0L | none in V0 scope | PATTERN-ONLY (Nibomo) | — | — | — | — | Native-only stacks |
| Analytics / cost / quota | RS (quota/usage seam) · V0L (analytics) | Canonical `usage_events` + `quota_ledger` adapted from donor usage tables | ADAPT | `request_summary` quota check, usage per job | UsageEvent, QuotaLedger, Entitlement | 30 (quota, one usage per job) | Done (seam) | Analytics follows the Learning App event contract; donor analytics code is PATTERN-ONLY |
| Deletion / export | RS (material revoke) · V0L (account/export) | Canonical `delete_material` + MoonlighC `delete-*` functions later | ADAPT | RPC + later donor functions | Deletion semantics §19 | Test 20 §8; donor Deno 40+13+35 green | Medium: donor functions target legacy tables | Nibomo recovery hardening: PATTERN-ONLY |
| Test / CI / release | RS | Learning App CI + spike gates; donor Flutter/Deno suites kept | CUSTOM CI; donor tests ADAPT; `subosito/flutter-action` DEPENDENCY (REUSE-0004) | `bootstrap-validation`, `spike-proof` (SQL + Deno), `flutter-proof` (client, CMD-0008) | — | Validator + negative suite; SQL 4/4; Deno 13/13; Flutter 5/5 in CI | Low | Nibomo release discipline: PATTERN-ONLY |

## 2. Quantified adaptation burden

| Measure | Value | How measured |
| --- | --- | --- |
| Donor source files reused unchanged | **0 files** (1 function: `set_updated_at`, REUSE-0001) | provenance register |
| Donor files adapted (patterns re-keyed) | **4** donor migrations (001, 004, 008, 010) → 2 canonical migrations | REUSE-0002 |
| Donor migrations replaced | **35 → 2** (787 lines vs 10,297); donor HEAD **97** SQL functions → **17** canonical | `pg_proc` counts on both DBs |
| New Learning App-owned files | 16 code files / ~2,080 lines (SQL 1,142 · Deno 699 · Dart 239) + docs | `wc` |
| New tests | SQL 4 files (~90 assertions), Deno 13, Flutter 5, validator +6 cases | runners |
| Inherited tests still green (donor, unchanged) | Flutter **633/633**, Deno **404/404** | LA-0010 |
| Inherited SQL tests | 10/26 at donor HEAD; 24/26 at their own step, so they must be **replaced**, not kept | LA-0010 |
| Donor client files touched by a canonical re-point | **38 / 112** Dart files (15.6k / 40.2k lines); 38 / 68 test files | grep for `StudyMaterial`, `materials.summary`, `MockAiService`, legacy job names |
| Donor Deno files touching legacy tables directly | **6** (the rest go through RPCs) | grep |
| Dependency additions / removals | +0 runtime; +1 dev (`flutter_lints`); OpenAI coupling removed from the spike path | pubspec / imports |
| Temporary compatibility / dual-write layers | **0** | schema review |
| Donor-specific semantics left in the canonical model | **0** (`subjects`, `materials.summary`, `study_generation_operations` rejected) | LA-0011 |
| New runtime / services | 0 (Postgres + Supabase Edge + Flutter only) | — |
| Rollback surface | Delete the spike branch/PR. The schema is greenfield, and there is no production data | — |

### Where the remaining adaptation cost sits (not done in the spike)

1. **Client re-point** (largest). 38 Dart files move from `StudyMaterial` / `materials.summary` to
   `library_items` / `artifacts`. `lib/app/app_state.dart` is a **4,163-line god object** that should be decomposed
   progressively while re-pointing (D-029 debt).
2. **PDF analysis pipeline** (`material_analysis_*`: ~20 SQL functions, 242 Deno tests). It must be re-keyed onto
   `generation_jobs/attempts` when PDF processing is admitted. Its state machine is richer than the spike's, so this
   is its own tranche.
3. **SQL regression suite at HEAD.** The donor has none, so the canonical suite started here must grow with each tranche.
4. **Mock AI removal in the client.** `MockAiService` is referenced from 7 client files. The client proof models
   show the replacement shape: the client never generates; it reads artifacts and job states.

## 3. Selector recommendation: **GO_ADAPT** (conditional)

Evidence for GO_ADAPT:

- **A meaningful substrate survives.** The donor's product shell, auth, storage, upload, extraction and deletion code
  is green at HEAD (633 Flutter + 404 Deno tests). Only about a third of the client files touch the concepts that change.
- **The canonical boundary is clean.** The canonical schema replaces the donor schema (no dual writes). All four load-bearing
  proofs (flow, isolation, idempotency, provider seam) pass on the Flutter/Supabase direction.
- **The donor's hardest-won mechanics transferred.** RLS/definer discipline, storage ownership, lease tokens, and
  dispatch ambiguity fitted the canonical model in two migrations.
- **A clean Flutter shell would pay the same canonical-schema cost *plus* rebuilding the shell.** That means about 112 files
  of auth/upload/extraction/deletion/UI with their test coverage. D-024/D-025 forbid counting that avoidable rewrite as donor cost.

Evidence against (why this is not unconditional):

- The client re-point is **measured statically, not executed**. The spike did not modify the donor Flutter app.
- The donor SQL tests are not a regression suite, and `phase_c_role_portability` fails at donor HEAD.
- `AppState` concentration is real maintenance debt.

Conditions attached to GO_ADAPT (proposed for Brain):

1. The canonical schema in `spike/architecture-proof/db/migrations` (evolved through ADRs) is the only data authority.
   Donor tables are **not** migrated in.
2. The first implementation unit re-points the donor client's material/summary path to the canonical tables and
   removes `MockAiService` from that path, with donor tests kept green or replaced one-for-one.
3. PDF analysis is re-keyed onto the canonical job model as its own tranche. It is not bolted on as a second job authority.
4. The canonical SQL regression suite is extended in every tranche.

FALLBACK_CLEAN_FLUTTER is **not** indicated. None of its triggers was observed: no invasive shell-wide rewrite, no
unavoidable dual authority, and the canonical job/artifact model fitted cleanly.

## 4. Final Engineering Test — selector recommendation (D-029)

| # | Question | Answer |
| --- | --- | --- |
| 1 | Necessary now? | Yes. It is the M4 exit criterion. |
| 2 | Simplest credible? | Yes. Adapting keeps working, tested plumbing; the canonical schema is small (12 tables, 17 functions). |
| 3 | Secure by default? | Yes. Tenant isolation is proven on the canonical model, and the donor security patterns are preserved. |
| 4 | Understandable? | Mostly. The canonical layer is clear. The donor `AppState` god object is debt with a remediation plan (condition 2). |
| 5 | Testable? | Yes. 633 + 404 donor tests plus the canonical suites. |
| 6 | Observable? | Yes. Job/attempt states are explicit; donor diagnostics tables exist for PDF analysis. |
| 7 | Replaceable/evolvable? | Yes. Provider seam, artifact types as data, no donor authority in the schema. |
| 8 | Privacy? | Acceptable. Owner-only data, deletion revokes derived rows, minimum provider context. |
| 9 | Operational cost? | Reasonable. No new runtime or service; the Supabase stack is unchanged. |
| 10 | Tomorrow? | Yes. The D-037 learner loop and a Sesli Öğren speech capability attach additively, with no destructive replacement or parallel truth (§5). |

**Open/unclear answer (declared):** #4 depends on executing condition 2. The client re-point is measured, not proven.

## 5. Review 003 corrections: selector consequences (CMD-0007 → CMD-0013)

### D-037 learner loop
LA-0011 §5 maps every D-037 authority. No row is BLOCKED. Tenancy, provenance, deletion of source-bound data, and
versioned-config substrate are FUTURE_COMPATIBLE. OutcomeContract, Objective/CompetencyRef, LearnerEvidence,
LearnerState, LearningMission, LearningAction and NBA policy are additive MIGRATION_DEBT. None needs destructive
replacement or a parallel truth. **GO_ADAPT is unaffected.** On the FALLBACK path the same learner-loop tables would
be needed in addition to rebuilding the shell.

### Layered composition and speech (D-042, D-062)
- **D-042 disposition: FUTURE_COMPATIBLE.** Nothing in the canonical schema, the RPCs or the D-037 attachment points
  depends on speech, so another Learning App can omit voice. Sesli Öğren composes voice as a product-local
  capability producing job-driven artifacts. There is no second learning-truth model and no speech leakage into
  learner-state/NBA.
- **D-041 speech-compatibility question, read through D-062: FUTURE_COMPATIBLE.** The generation seam pattern proves
  a replaceable, fakeable, server-side, cost-recording capability boundary. The Speech Capability boundary itself
  is additive MIGRATION_DEBT before provider lock-in. Companion/product direction is not an M4 matter (CMD-0012/0013).

### Hardening debt carried (not built in M4; not selector blockers)

| ID | Debt | Why it matters | Verification point |
| --- | --- | --- | --- |
| H1 | **Quota concurrency.** `request_summary` checks quota server-side, but concurrent requests for *different* materials can both pass the check before either consumes. | Over-admission of billable work. | Before any real billable provider: atomic reservation/consumption (row lock or conditional update on `quota_ledger`) plus a concurrent-request test. |
| H2 | **Relational tenant-owner integrity.** Related rows each carry `account_id` with ordinary FKs. Client writes are RPC-only and tested, but a privileged/server bug could link rows across owners. | Defence in depth for privileged writes. | Before load-bearing server writes: composite `(id, account_id)` FKs or equivalent invariant checks, with negative tests. |
| H3 | **Real Supabase surface.** The spike runs on a Postgres shim; PostgREST, GoTrue and Storage HTTP are not exercised. Rows are revoked on deletion, but object cleanup is not proven. | Privacy/retention contract. | Before production-shaped acceptance: real Supabase-compatible run proving auth, storage access, object deletion/revocation. |
| H4 | **Flutter CI.** Was local-only at the reviewed head. | Exact-head evidence for the client. | **Addressed for the proof client by CMD-0008:** `flutter-proof.yml` runs pub get, format, analyze and test on the `.flutter-version` pin. Extend it to the real client when that becomes load-bearing. |
| H5 | **Locale persistence.** The harness worker defaults the output locale to `tr-TR` and the job does not store the requested locale. | D-034 explanation-locale fidelity. | With the first real generation path: persist the requested locale on the job (additive column). |
