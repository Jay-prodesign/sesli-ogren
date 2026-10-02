# ENGINEER RETURN — CLAUDE_HANDOFF_001 — V0 Architecture Spike

## Verdict

**ARCHITECTURE_PROOF_PASS / GO_ADAPT. Brain Review 004 accepted the Architecture Proof at immutable reviewed head `0327d2e5b854df1c9923c65ed88f77151cfe9eed`. CMD-0014 / RET-0006 are closure projection only.**

- Review 003 (reviewed head `9fb2d9b`) was CHANGES_REQUIRED.
- The corrections, CMD-0004 … CMD-0013, are answered cumulatively by [RET-0005](returns/RET-0005.md).
- [RET-0004](returns/RET-0004.md) answers CMD-0002, and [RET-0003](returns/RET-0003.md) answers CMD-0003.

The engineer does not self-declare PASS. Sections 1–16 carry the original Architecture Proof evidence, updated where
Review 003 changed it. Sections 17–22 add the correction-round evidence.

## 1. Execution identity and protected boundaries

| Field | Value |
| --- | --- |
| Repository | https://github.com/Jay-prodesign/sesli-ogren (PUBLIC) |
| Branch | `spike/v0-architecture-proof`, created from the reviewed bootstrap head `433c26cf5fa75a37b66b1f74dd6a133ae4d3407a` |
| Draft PR | [#2](https://github.com/Jay-prodesign/sesli-ogren/pull/2), stacked on `chore/repository-bootstrap`, draft, unmerged |
| Final head | **External binding (CMD-0009):** `PR_HEAD_AT_REVIEW` / `GITHUB_PR_HEAD`, meaning the current PR #2 head resolved from GitHub after push. No committed file names its own commit SHA. The stale "content head vs final head" wording is retired. |
| Previous reviewed head | `9fb2d9b34c236c3c8196a5b0f411a5c6836179d1` (Review 003) |
| `main` / PR #1 | `52616b4` untouched / draft, unmerged, untouched |
| Protected actions | None: no merge, deploy, release, LICENSE change, paid provider, credentials, secrets, force-push, main mutation, M5 admission, or cross-project mutation. Local `main` was never used as the integration branch. |

## 2. LA-0009 control plane

CMD-0002 and CMD-0003 were transcribed from Drive and acknowledged in order. The Review 003 chain, CMD-0004 … CMD-0013,
followed on 2026-09-30, each with its classification from HANDOFF_COMMAND_AUTHORITY_AUDIT_001 (§17).
TASKS: M0 is DONE and M1 is ACTIVE with LA-0009…LA-0017. D-029/D-028 are projected into AGENTS.md §14, CLAUDE.md,
`.claude/rules/engineering-quality.md` and the plan template; D-031 is projected into AGENTS §8. The bus now has PARTIAL
checkpoint returns. Validator and negative suite: green.

## 3. LA-0010 donor currentness and reuse ([detail](../architecture/spike/LA-0010-upstream-audit.md))

All six candidates are pinned at exact commits with licences read at those commits: MoonlighC MIT, Open Notebook MIT,
OpenTutor MIT, Nibomo MIT, NotebookLM-Lite Apache-2.0, vercel/ai Apache-2.0. Only `vercel/ai` drifted from Brain's pin.
MoonlighC suites were executed: migrations **35/35**, Flutter **633/633**, Deno **404/404**, SQL tests **10/26 at HEAD**
(24/26 at their authored step). Its SQL tests are step scripts, not a HEAD regression suite. No donor code was imported before classification.

## 4. LA-0011 canonical model ([detail](../architecture/spike/LA-0011-canonical-model-mapping.md))

All 15 canonical objects are mapped. There is one authority per concept:

- The donor `public.materials` mega-object is **split** into Material, SourceAsset, ExtractedContent and Artifact.
- The donor's two generation systems are **unified** into `generation_jobs/attempts`.
- The Summary is a versioned Artifact. `materials` has no summary column (test-enforced).
- There are no dual writes and no donor tables in the canonical schema.

## 5. LA-0012 provider seam ([detail](../architecture/spike/LA-0012-provider-seam.md))

`StructuredGenerationCapability` is Learning App-owned and has **no imports**. It ships with a deterministic fake, a
dependency-free fetch adapter, and a worker that records dispatch before calling the provider. The Vercel AI SDK works on
Deno, but it is 307.7 KB minified against 3.3 KB for the fetch adapter, pulls in 11 packages against 0 (including an
unused Gateway client), and releases 35 times in 30 days. It is therefore **not adopted**; the concrete reason and a
revisit trigger are logged. No live provider was called and no Gateway was used.

## 6. LA-0013 bounded end-to-end

The chain is proven in SQL, in a Deno worker against real Postgres, and in a separate session for reopening:

1. authenticated user;
2. Material;
3. SourceAsset;
4. ExtractedContent;
5. Job;
6. Attempt;
7. deterministic Summary;
8. persistent Artifact;
9. Library projection;
10. reopen from persistence.

The Flutter contract package decodes the **actual owner-visible DB rows** into canonical models. The proof-only status
card covers queued, processing, success, failure and retry. It is labelled as proof UI (D-028), not product design.

## 7. LA-0014 isolation

Covered by [detail](../architecture/spike/LA-0013-0015-flow-isolation-idempotency.md) and `20_tenant_isolation.sql`:

- anon is denied;
- a request with no subject is refused;
- user B sees 0 rows in every canonical table and in the library;
- direct writes are denied;
- cross-user RPCs return a **non-revealing** error;
- worker RPCs are denied to clients;
- storage paths grant nothing;
- clients cannot read or write lease tokens;
- deletion revokes all derived access.

No cross-user access was observed.

## 8. LA-0015 retry, idempotency and lineage

Covered by `30_job_idempotency.sql` and the Deno integration test:

- same key → same job; same request with a new key → same live job (fingerprint plus a unique partial index);
- key reuse on another material is rejected;
- after a retryable failure there is no auto re-dispatch, and a user retry creates a linked attempt;
- a stale lease or token cannot mutate the job;
- after a crash that follows dispatch the request is **never resent**; it is reconciled instead;
- after a crash before dispatch the job re-runs safely;
- each job has one artifact, one usage event and one quota consumption;
- regeneration is a separate intent;
- quota is enforced on the server.

## 9. LA-0016 burden and selector ([detail](../architecture/spike/LA-0016-layered-donor-decision.md))

Donor files copied verbatim: 0; one function (`set_updated_at`) was reused directly. Four donor migrations were adapted.
The migrations shrink from 35 to 2 and the SQL functions from 97 to 17. The canonical re-point touches **38/112** donor
Dart files, and there are **0** dual-write layers. The full D-025 capability matrix covers 17 rows.

**GO_ADAPT conditions:**
1. The canonical schema is the only authority.
2. The first unit re-points the donor client's material/summary path and removes `MockAiService` from it.
3. The PDF analysis pipeline is re-keyed onto the canonical job model as its own tranche.
4. The canonical SQL regression suite grows every tranche.

## 10. Tests and evidence (commands run)

| Suite | Result |
| --- | --- |
| `spike/architecture-proof/db/run_sql_suite.sh` (Postgres 16.13 + shim) | migrations 2/2, tests **4/4** (~90 assertions) |
| `deno lint` / `deno check` / `deno test -A` (Deno 2.9.7, `LA_TEST_DB` set) | clean / clean / **13/13** |
| `flutter analyze` / `flutter test` (Flutter 3.47.5) | clean / **5/5** |
| Mutation checks | **3/3** caught |
| `python3 scripts/validate_bootstrap.py` / negative suite | green / **52/52** (40 before Review 003; the earlier "41" was a counting error) |
| Rollback rehearsal (worktree at `433c26c`) | base validator + negatives green without the spike |
| Secret sweep (tokens, JWT, keys, private keys, secret files) | clean |
| CI `bootstrap-validation` | green on all heads except `521ec04` (fixed in `c894bd8`) |
| CI `spike-proof` (read-only) | re-runs the SQL and Deno proofs; green at `9fb2d9b` (run 36597243597); re-runs on the final head |
| `flutter-proof` (CMD-0008, read-only) + local Flutter 3.47.5 | pub get / format / analyze / test on `spike/architecture-proof/client`; local: format exit 0, analyze clean, **5/5** |

## 11. Provenance

- REUSE-0001: MoonlighC `set_updated_at`, DIRECT-REUSE.
- REUSE-0002: MoonlighC tenancy, storage and job mechanics, ADAPT.
- REUSE-0003: `flutter_lints` 6.0.0, dev DEPENDENCY.
- REUSE-0004: `subosito/flutter-action` v2.23.0 @ `1a449444…`, DEPENDENCY (CI), MIT.
- REUSE-0005: `actions/checkout` v4.4.0 @ `11d5960a…`, DEPENDENCY (CI), MIT.
- Rejected approved candidate: `vercel/ai` 7.0.118.
- The MIT notice is kept at `docs/provenance/licenses/`. No private Drive text was copied.

## 12. D-029 disposition

- **Where it was integrated:** AGENTS.md §14, CLAUDE.md, `.claude/rules/engineering-quality.md`, the plan template,
  a `Quality considerations (D-029)` section in every M1 plan, and validator checks.
- **Final Engineering Test:** recorded for the canonical split (LA-0011), SDK vs fetch (LA-0012), the idempotency
  design (LA-0013–15), and the selector (LA-0016).
- **Declared open item:** #4 for the selector. The client re-point is measured, not executed.
- **N/A:** LA-0009 (governance only) and LA-0014 (verification, no new design).

## 13. Known limitations and debt

1. A Supabase shim was used instead of the CLI/Docker stack, so the PostgREST, GoTrue and Storage HTTP layers are not exercised (hardening debt H3).
2. The donor client is not yet re-pointed to the canonical tables. The count of 38 Dart files is static measurement.
3. `lib/app/app_state.dart` is a 4,163-line god object and should be decomposed while re-pointing.
4. The donor PDF analysis pipeline (~20 SQL functions, 242 Deno tests) still needs re-keying onto canonical jobs.
5. The canonical SQL suite must grow with every tranche; the donor has no HEAD regression suite.
6. Failed-but-executed attempts record no UsageEvent. Attempt-level cost events are needed before real providers are used.
7. The fetch adapter classes pre-send transport errors as `ambiguous`. This is conservative.
8. ~~Flutter client tests run locally only.~~ Addressed by `flutter-proof` (CMD-0008, H4).
10. See §20 for the Review 003 hardening debt (H1–H5) and §18 for the D-037 learner-loop migration debt.
9. The donor migration `phase_c_role_portability` test fails at donor HEAD. This is a donor issue and is not inherited.

## 14. Rollback

Delete `spike/v0-architecture-proof` and close PR #2 unmerged (Product Owner / Brain decision). The schema is
greenfield, there is no production data, and `main` and PR #1 are untouched. The rehearsal shows the base remains green.

## 15. Next recommended implementation unit

Product content follows the admitted V0 scope (D-054 / V0_PRODUCT_SCOPE_v2.0), not the old artifact grid (CMD-0013).
**Foundation unit, per condition 2.** Import the MoonlighC Flutter shell under a new admitted task with REUSE entries,
apply the canonical migrations, and re-point the material → summary path (`StudyMaterial` / `materials.summary` →
`library_items` / `artifacts`, `MockAiService` → server generation). Keep donor tests green or replace them one-for-one.
The first Owner Preview follows D-032.

## 16. Unresolved owner / architecture decisions

- **Provider/model vendor and credentials (D-031, paid gate).** Needed before any live generation (and H1 must be closed first). Not needed for the proof. The same gate applies to any speech provider (D-062).
- **Donor client import into this repository.** This is a D-024 reuse action within the next admitted task. Brain should
  confirm the admission.
- **Bridge activation (AUTO_AGENT_BRIDGE_BLOCKED)** remains an optional Founder gate.

## 17. Review 003 command chain (CMD-0004 … CMD-0013)

The chain was transcribed from Drive in ID order. Titles and decision IDs only; no private bodies or file IDs.
Each command is classified per HANDOFF_COMMAND_AUTHORITY_AUDIT_001 and answered by RET-0005 (`Also answers`).

| Command | Current classification | Effect |
| --- | --- | --- |
| CMD-0004 (D-034) | Partially superseded | Locale semantics and eval readiness applied; speech via D-062 |
| CMD-0005 (D-035) | Historical | No shared Speech Service (still valid) |
| CMD-0006 | Current | §21 Tooling Blockers |
| CMD-0007 (Review 003) | Current | Items A–E, hardening debt |
| CMD-0008 | Current | Flutter pin + `flutter-proof` CI |
| CMD-0009 | Current | External head binding in the validator, state and RET |
| CMD-0010 (D-041) | Partially superseded | Speech compatibility only, via D-062 |
| CMD-0011 (D-042) | Voice-optional core current | D-042 disposition |
| CMD-0012 (D-043) | Current guard | No product hierarchy encoded |
| CMD-0013 (D-053/D-054) | Current guard | Artifact-grid rows reworded; no product UI |

## 18. D-037 compatibility / debt map

Full table: [LA-0011 §5](../architecture/spike/LA-0011-canonical-model-mapping.md).
- **FUTURE_COMPATIBLE:** tenant/RLS ownership, provenance/trust lineage, source-bound deletion, and links to
  Material/SourceAsset/Artifact/Job/Attempt. Rule/config version lineage has a FUTURE_COMPATIBLE substrate.
- **MIGRATION_DEBT (additive):** OutcomeContract, Objective/CompetencyRef, LearnerEvidence, LearnerState (with evidence
  confidence/coverage kept separate from mastery/readiness), LearningMission, LearningAction, deterministic/versioned NBA
  policy with reason codes, learner-state recompute lineage, and learner-loop revocation semantics.
- **BLOCKED:** none. No row needs destructive replacement or parallel truth.
- `evidence_refs` are source citations and must not be overloaded as learner evidence.
- The learner loop is **not** modeled or implemented in M4.

## 19. D-034 / speech / evaluation / layered-engine compatibility

Detail: [LA-0012 §6](../architecture/spike/LA-0012-provider-seam.md) and LA-0011 §6.

1. **Language contracts (Turkish-first, English-ready).** Compatible.
   - uiLocale = `accounts.locale`;
   - content/learning locale = `outputLocale` → artifact `language`;
   - source and voice locale are additive columns later (debt H5 covers persisting the requested locale).
2. **Structured generation.** Provider-neutral (PASS).
3. **Speech.** Implementation N/A_BY_SCOPE. The absence of a SpeechProvider or shared Speech Service is not debt.
   Under D-062, a product-local, replaceable Speech Capability boundary is required before provider lock-in. That is
   **FUTURE_COMPATIBLE**, with additive debt.
4. **Shared-intelligence boundaries.** No duplicate generic AI/speech/eval control plane exists. There is one narrow
   contract and one adapter.
5. **Evaluation.** A replaceable attachment point exists (fakes, typed validation, schema/version fields). No framework.
6. **D-042 layered composition: FUTURE_COMPATIBLE.** The voice-optional core has no speech dependency. Sesli Öğren voice
   composes on top with no second learning truth and no leakage into learner-state/NBA.
7. **D-041 compatibility, read through D-062: FUTURE_COMPATIBLE.**

## 20. Hardening debt (carried, not built; not selector blockers)

Detail: [LA-0016 §5](../architecture/spike/LA-0016-layered-donor-decision.md).

| ID | Debt | Verification point |
| --- | --- | --- |
| H1 | Quota concurrency: parallel requests can over-admit | Atomic reservation plus a concurrency test, before any billable provider |
| H2 | Relational tenant-owner integrity for privileged writes | Composite owner FKs or invariants plus negative tests, before load-bearing server writes |
| H3 | Real Supabase PostgREST/GoTrue/Storage deletion and access proof | A real Supabase-compatible run, before production-shaped acceptance |
| H4 | Flutter CI | **Addressed for the proof client** (`flutter-proof`); extend to the real client later |
| H5 | Output-locale persistence on jobs | Additive column with the first real generation path |

## 21. Tooling Blockers (CMD-0006)

| Blocked operation | Task / sub-step | Evidence | Work that continued | Criteria unmet | Founder/provider action |
| --- | --- | --- | --- | --- | --- |
| Official Flutter SDK download | LA-0013 (client proof runtime), LA-0017 | Permission classifier denial (twice) in the Claude Code session. No bypass attempted. | SQL, Deno, audits, mapping, provenance and the validator all continued | None now. The SDK was later installed from the official source with its sha256 verified, and client tests pass locally and in `flutter-proof` | None remaining |
| Edits to agent-instruction files derived from Drive commands (AGENTS.md / CLAUDE.md / rules) | LA-0009 (D-029 projection) | Classifier treated Drive-derived instructions as untrusted ("instruction poisoning"). No obfuscation attempted; the work was paused and stashed. | Read-only validation and evidence preparation | None now. The edits landed after the Founder's direct authorization in-session | None remaining |
| Supabase CLI / Docker stack | LA-0013 … LA-0015 (real platform surface) | Not available in the execution container | Postgres 16 + a minimal Supabase shim covered SQL/RLS/RPC semantics | PostgREST/GoTrue/Storage HTTP not exercised (debt H3; not an M4 acceptance criterion) | None for M4 |
| Brain GitHub writes | Command transport | Brain's integration receives 403 (recorded by Brain) | The engineer transcribed CMD-0002 … CMD-0013 from Drive | None | Optional: grant Brain write access, or keep transcription |

The Founder is not used as a routine command courier. Local Windows desktop builds (missing C++ workload) are a
**NON_BLOCKING** local limitation (CMD-0008).

## 22. CMD-0008 Flutter integration evidence

- `.flutter-version`: `3.47.5`. No `.fvmrc`.
- No `.vscode` settings or tasks, and no replacement `.gitignore`/`.gitattributes`. The existing ignore rules already
  cover the client's generated files.
- `.github/workflows/flutter-proof.yml`:
  - triggers on pull requests touching `.flutter-version`, `spike/architecture-proof/client/**` or the workflow itself;
  - `contents: read`; no secrets;
  - `actions/checkout@11d5960a…` (v4.4.0) with `persist-credentials: false`;
  - reads the pin into a step output;
  - `subosito/flutter-action@1a449444…` (v2.23.0) with `cache: false` and `pub-cache: false`;
  - runs `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test` in
    `spike/architecture-proof/client`.
- Format delta: 3 admitted client files (`lib/domain/models.dart`, `lib/ui/job_status_card.dart`,
  `test/contract_test.dart`) received layout-only `dart format` changes. Analyze and tests are unchanged and green.
- The stale "Flutter local-only" comment in `spike-proof.yml` and the bootstrap-only README status were corrected minimally.
- The optional PowerShell helper was omitted.


## 23. Brain Review 004 closure projection (CMD-0014 / RET-0006)

- Brain Review 004 accepted the architecture at `0327d2e5b854df1c9923c65ed88f77151cfe9eed`; that SHA remains the immutable reviewed architecture head.
- Founder explicitly authorized ChatGPT on 2026-10-02 to act as a temporary bounded engineering delegate while Claude usage is unavailable.
- This closure changes only repository control-plane/evidence files. No architecture/product code, schema, provider, UI, speech implementation or release behavior is changed.
- M1 and LA-0009 … LA-0017 are projected DONE. The future M5 Golden Learning Slice remains NOT_EXECUTABLE and has no implementation task allocation.
- Any later PR #2 commit is a closure/control-plane projection and must not be represented as the Review 004 architecture head.
- Protected actions remain untouched: no merge, deploy, release, paid-provider spend, credentials/secrets, production mutation, destructive migration, licensing-posture change or cross-project mutation.
- Closure validation is resolved from GitHub CI after the projection commit; RET-0006 records the external-binding limitation rather than inventing a self-referential commit SHA.
