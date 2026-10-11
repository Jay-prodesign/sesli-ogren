# M5 GLS-083 Synthetic Adversarial Review — 2026-10-05

- Project: Learning App / Sesli Öğren
- Task: LA-0022
- Synthetic runtime candidate: `64579d48bcf9c33f4c709927a0e453349efb7c5b`
- Review mode: **synthetic adversarial multi-pass review by the same Brain context**
- Independence claim: **NONE**
- GLS-083 replacement claim: **NONE unless Founder explicitly waives external independence**
- Runtime/build execution: pending final bounded D-072 batch

## Synthetic disposition

**SYNTHETIC_PASS — NO UNRESOLVED BLOCKER/HIGH FOUND AFTER S-003 CORRECTION.**

This materially reduces M5 code-risk but does not self-grant the independent
GLS-083 gate because the same Brain context performed prior static review and
the S-003 remediation.

## Review passes

### Pass A — authentication / tenant isolation

Reviewed:
- `app/lib/src/auth/supabase_learner_auth.dart`
- `app/lib/src/app/sesli_ogren_app.dart`
- `app/lib/src/app/app_runtime.dart`
- learner-scoped SQLite query/update/delete/raw-query surfaces
- server Recall RLS / authenticated RPC ownership checks

Findings:
- production bootstrap fails closed when Supabase configuration/auth is absent;
- production bootstrap does not fall back to `localM5LearnerFixture`;
- learner identity derives from the Supabase user subject;
- SQLite CRUD/raw-query scan found no query/update/delete path lacking learner scope;
- server Recall action/evidence/session reads and RPC ownership checks are account-scoped.

Disposition: **PASS_STATIC / LIVE_AUTH_PENDING_BATCH**.

### Pass B — source authority / stale truth

Reviewed:
- current-source lookup;
- source supersession;
- extracted-content invalidation;
- stale Recall action checks;
- delete behavior;
- continuation/reopen authority.

Findings:
- new evidence requires the current authoritative source;
- source supersession clears active attempts/current derived state and invalidates prior extraction;
- old evidence may remain as historical evidence but cannot become current state/continuation for the new source;
- deleted material clears current source and derived continuation;
- Recall service rejects actions whose source is no longer current.

Disposition: **PASS_STATIC**.

### Pass C — Recall assistance / evidence / state / idempotency

Reviewed:
- active attempt uniqueness;
- hint / answer-exposure monotonicity;
- direct-store canonical recomputation;
- evidence-before-state;
- same-attempt replay;
- conflicting replay;
- answer-exposure laundering paths;
- server RPC assistance/session semantics.

Findings:
- one active attempt per learner/material is enforced locally;
- assistance cannot be downgraded from answer exposure to hint;
- new local evidence requires matching active attempt;
- direct persistence cannot fabricate outcome/state/next-action because canonical policy is recomputed;
- conflicting same-attempt replay fails closed;
- server answer exposure is canonical and maps to `answer_exposed / not_assessed`;
- post-freeze SQL test hardening now exercises unassisted replay/idempotency, hinted success, answer exposure, monotonicity, cross-user rejection and post-submit support mutation.

Disposition: **PASS_STATIC / RPC_EXECUTION_PENDING_BATCH**.

## Finding S-003 — RESOLVED / HIGH

Area:
- versioned learning-truth semantics / audit provenance

Files:
- `app/lib/src/domain/learning_truth.dart`
- `server/db/migrations/0004_server_authoritative_recall_assistance.sql`
- `server/db/tests/40_recall_learning_truth.sql`

Violated invariant:
- GLS-026 / GLS-083 deterministic versioned policy semantics.

Failure scenario before correction:
- Flutter/local Recall policy correctly used `recall-evidence-v2` and
  `recall-state-v2` after answer-exposure semantics became canonical;
- server migration 0004 changed the same semantics but continued writing new
  evidence/state as `recall-evidence-v1` / `recall-state-v1`;
- two different policy semantics could therefore share the same version label,
  weakening audit/replay determinism and parity claims.

Correction:
- commit `64579d48bcf9c33f4c709927a0e453349efb7c5b`;
- historical v1 evidence remains labeled v1;
- evidence constraint now permits historical v1 plus new v2;
- new server Recall evidence is written as `recall-evidence-v2`;
- existing mutable LearnerState projections migrate to `recall-state-v2`;
- new server LearnerState writes use `recall-state-v2`;
- test commit `4c3d5bd428a45b0cd95cc5c668dbd201dbd5be9f` asserts new v2 evidence/state provenance.

Status: **RESOLVED / SQL EXECUTION PENDING**.

### Pass D — migration / recovery

Reviewed:
- local schema upgrades through v6;
- historical evidence version handling;
- derived projection repair;
- server 0003 → 0004 migration semantics.

Findings:
- local migration preserves historical evidence rule version while recomputing current derived state under the newer state policy;
- server S-003 correction now follows the same provenance principle instead of relabeling historical evidence;
- repair requires current source + durable evidence and recomputes canonical state/next action.

Disposition: **PASS_STATIC / MIGRATION_EXECUTION_PENDING_BATCH**.

### Pass E — telemetry / privacy / untrusted PDF

Reviewed:
- ordinary operational event schema;
- emitted UI events;
- PDF byte/page/text bounds;
- parser error handling.

Findings:
- operational telemetry stores identifiers, enums, version/reason/status,
  duration and error class; reviewed paths do not write raw source text or raw
  free-form learner answer;
- PDF ingest caps input at 25 MiB before parsing;
- parser caps page count at 500 and extracted text at 200k characters;
- malformed/no-text/oversized paths fail closed;
- native parser resource/performance behavior still requires runtime evidence.

Disposition: **PASS_STATIC / NATIVE_RUNTIME_PENDING**.

### Pass F — Companion / UI truth boundary

Reviewed:
- `CompanionView`;
- phase → Companion-state mapping;
- Reduced Motion;
- result/continuation state mapping.

Findings:
- Companion has no path to write LearnerEvidence, LearnerState or NextLearningAction;
- Reduced Motion stops Companion motion;
- text flow remains load-bearing.

Non-blocking product note:
- `retrievedOnce` currently maps to the visual `success` state whose semantic
  label says “Düğüm başarıyı kutluyor”. This does not claim mastery in data/copy,
  so it is not an M5 truth blocker, but D-075's Character / Asset Behavior Gate
  should revalidate the celebration intensity in the post-M5 Desire /
  Engagement / Core-Loop Premise Audit to avoid over-rewarding one bounded
  retrieval observation.

Disposition: **M5_PASS_STATIC / POST_M5_BEHAVIOR_REVALIDATE**.

## Residual external/runtime evidence

Still not proven by this synthetic review:
- real Supabase anonymous authenticated session;
- Flutter 3.47.5 lockfile/transitive resolution;
- Dart format/analyze/test execution;
- native PDF parser execution;
- strengthened PostgreSQL SQL/RPC suite execution;
- Android profile build;
- iOS profile no-codesign build;
- runtime accessibility evidence;
- physical VoiceOver/TalkBack/device evidence remains deferred under D-068.

## Final synthetic conclusion

No unresolved **BLOCKER/HIGH** is known after S-003 correction.

Synthetic review recommendation:
**PROCEED TO EXTERNAL INDEPENDENCE OR, ONLY IF FOUNDER EXPLICITLY WAIVES THAT GATE, PROCEED TO LOCKFILE + SINGLE BOUNDED D-072 VALIDATION BATCH.**

This document is supplemental evidence and must not be mislabeled as an
independent GLS-083 review.
