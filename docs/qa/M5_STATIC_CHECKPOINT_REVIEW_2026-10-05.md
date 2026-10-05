# M5 Static Checkpoint Review — 2026-10-05

- Task: LA-0022
- Branch: `feat/m5-golden-learning-slice`
- Runtime implementation candidate reviewed before control-plane-only commits: `01670f42029ef228706c4a772594102e5656ebdf`
- Mode: Brain/static checkpoint review; **not** the independent GLS-083 review
- Runtime/build execution: pending the single bounded D-072 batch

## Quality gate

**PASS WITH PENDING RUNTIME EVIDENCE.**

No known code-level BLOCKER/HIGH remains from this static pass after the correction below. This does not grant M5 PASS because live Supabase auth, exact dependency lock/build execution, GLS-083 independent review and product/learning/creative/accessibility dispositions remain open.

## Finding S-001 — RESOLVED / PENDING BATCH

- Severity before correction: **HIGH**
- Area: server-side Recall assistance / learning-truth integrity
- Files:
  - `server/db/migrations/0004_server_authoritative_recall_assistance.sql`
  - `server/db/tests/40_recall_learning_truth.sql`
- Violated invariant: GLS-023 / GLS-029 / GLS-083 assistance integrity
- Failure scenario: the local app distinguishes `hint` from `answerExposed`, but the M5 server delta previously stored only `hint_used`. A server-backed “show answer” path therefore had no canonical answer-exposure state and could later classify an exact submitted answer as unassisted `correct` / `retrieved_once`.
- Smallest safe correction applied:
  - canonical assistance is now `none | hint | answer_exposed`;
  - hint cannot downgrade prior answer exposure;
  - explicit `reveal_recall_answer` RPC marks answer exposure before returning the answer;
  - `answer_exposed` is a distinct evidence outcome and maps to `not_assessed`;
  - server next-action reason is derived from canonical outcome so answer exposure and unknown remain semantically distinct;
  - regression/schema checks cover the new RPC, assistance column and outcome-specific reason.
- Correction commits:
  - `b0d5df8adc0f8155946cc308f280651022ee9a13`
  - `01670f42029ef228706c4a772594102e5656ebdf`
- Remaining evidence: real PostgreSQL/Supabase-shim execution in the bounded M5 batch.

## Authentication boundary — STATIC_PASS / LIVE SESSION PENDING

- Production `SesliOgrenApp` calls `SupabaseLearnerAuth.authenticate()` before `AppRuntime.open(...)`.
- Missing `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` fails closed.
- Failed anonymous authentication fails closed; no production fallback to `AppRuntime.localM5LearnerFixture` is present in the runtime bootstrap.
- Only project URL and publishable client key are accepted at this boundary; no service-role/secret key is present in the reviewed client bootstrap.
- The authenticated Supabase user UUID becomes the `LearnerId`.
- Remaining evidence: one real configured project with anonymous sign-in enabled and observed authenticated session/user ID.

## Learning-truth boundary — STATIC_PASS / BATCH PENDING

- Active Recall attempt identity is required before new evidence.
- Canonical assistance is consulted before evaluation.
- Local policy keeps `correct`, `helpedCorrect`, `answerExposed`, `partial`, `incorrect`, and `unknown` distinct.
- `answerExposed` and `unknown` cannot become positive learner state.
- Evidence precedes derived state/next action.
- Stale source/action lineage fails closed.
- Remaining evidence: execute authored SQLite and server SQL regression suites.

## Privacy / telemetry boundary — STATIC_PASS / BATCH PENDING

- Ordinary operational telemetry records identifiers, enums, versions, durations and error class.
- Reviewed runtime path does not send raw source text or raw free-form learner answer into operational telemetry.
- Telemetry failure is explicitly non-authoritative and non-blocking.
- Remaining evidence: execute telemetry tests and perform final runtime log sweep.

## Reproducibility

Still **BLOCKED** for M5 PASS:
- `app/pubspec.lock` must be produced by Flutter 3.47.5 dependency resolution and committed.
- Flutter/Dart analyze/tests/builds must run in the one bounded checkpoint environment.
- Server migrations/tests must execute against real PostgreSQL semantics through the existing validation harness.

## Independent-review boundary

This review is intentionally not counted as GLS-083 because the same ChatGPT/Brain execution stream identified and corrected S-001. The independent reviewer must inspect the corrected candidate, including the server assistance delta, and return REVIEW_PASS / CHANGES_REQUIRED / BLOCKED.


## Dependency / native-target compatibility — STATIC_PASS

Current package constraints were checked against the pinned Flutter/Dart line before the runtime batch:
- `pdfrx 2.6.1` requires Flutter 3.47+ / Dart 3.13+ and iOS 15+; repository pin is Flutter 3.47.5, `app/pubspec.yaml` requires Dart ^3.13.4, and the iOS Xcode project is set to deployment target 15.0.
- direct low-level PDF access already calls `pdfrxFlutterInitialize()` lazily before `PdfDocument.openData`.
- `sqflite 2.4.4`, `supabase_flutter 2.17.2`, `crypto 3.0.7` and `flutter_lints 6.0.0` have minimum Dart requirements below the M5 Dart 3.13.4 line.
- exact transitive compatibility remains a lockfile/runtime-batch claim only; this static check does not replace `flutter pub get`.

No dependency/toolchain incompatibility blocker is known from static review.
