# M5 Golden Learning Slice — Checkpoint Acceptance Matrix

Status vocabulary used here:

- **STATIC_PASS** — implementation/readback evidence is credible at the current branch, but runtime batch may still be pending where stated.
- **PENDING_BATCH** — requires the single bounded D-072 checkpoint validation batch.
- **PENDING_REVIEW** — requires an explicit independent/product/learning/creative/accessibility disposition.
- **NOT_APPLICABLE** — conditional requirement is outside the admitted M5 slice.
- **DEFERRED_D068** — physical mobile-readiness evidence is intentionally deferred under D-068.
- **BLOCKED** — a hard unresolved blocker exists.

This matrix does **not** declare M5 PASS by itself.

## Candidate identity

- Repository: `Jay-prodesign/sesli-ogren`
- Branch: `feat/m5-golden-learning-slice`
- Frozen runtime implementation candidate: `e576ca177ff8872cbbfc4f127eb016cefa7f611c`
- Checkpoint-control-only reconciliation commits may follow this SHA; they do not widen runtime feature scope.
- Flutter pin: `.flutter-version` = 3.47.5.
- Routine GitHub Actions: OFF under D-072.
- Current ChatGPT execution container cannot reach GitHub over the network and has no established Flutter/Dart checkpoint environment; runtime/build evidence must come from one bounded checkpoint batch in a supported environment.
- Known reproducibility gap: `app/pubspec.lock` is currently absent for the new M5 dependencies and must be generated/committed before a PASS verdict.
- Production learner bootstrap now requires a real Supabase Auth session before learner-scoped data opens; live project configuration/anonymous-auth enablement remains checkpoint evidence, not a repo secret.
- Known authentication gap: production code now fails closed unless `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` are provided and a real Supabase session can be established; live project/auth configuration evidence is still pending.

## A — Source truth and grounding

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-001 | STATIC_PASS | One learner-scoped Material points to one current immutable SourceVersion; Recall/evidence/state/reopen use the same version identity. |
| GLS-002 | STATIC_PASS | Recall is deterministic cloze derived directly from ExtractedContent; feedback shows correct answer + source excerpt. No load-bearing AI generation exists in M5. |
| GLS-003 | STATIC_PASS | SourceVersion, ExtractedContent, page/offset anchors, RecallAction and LearnerEvidence retain lineage; supersede/delete invalidates current projections. |
| GLS-004 | STATIC_PASS / PENDING_BATCH | Empty/oversized/malformed PDF/text paths fail closed; authored tests include malformed/oversized cases and real PDF extraction. Native parser execution remains batch evidence. |

## B — Identity, tenant isolation and untrusted input

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-010 | BLOCKED | Store/query paths are learner-scoped and cross-user negative tests are authored, but the production runtime previously used a local fixture. Supabase-authenticated runtime code is now present; PASS requires a real project/session configuration plus checkpoint evidence that the runtime learner ID comes from the authenticated Supabase subject. |
| GLS-011 | STATIC_PASS | Evidence/state/next-action and support history are enforced at the domain/store boundary. New evidence requires a matching active Recall attempt. |
| GLS-012 | STATIC_PASS | Source text is parsed as data; the admitted Recall path has no prompt/model instruction authority surface. |
| GLS-013 | STATIC_PASS / PENDING_BATCH | Text/PDF byte/character/page bounds and malformed PDF checks exist; native parser behavior remains batch evidence. |
| GLS-014 | STATIC_PASS | Operational events store IDs/enums/durations/error classes, not raw source text or raw learner answer text. |

## C — Learning action, evidence and state integrity

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-020 | STATIC_PASS | Source-grounded Recall is a meaningful active retrieval action. |
| GLS-021 | STATIC_PASS | LearnerEvidence is inserted before the derived LearnerState/NextLearningAction projection in one transaction. |
| GLS-022 | STATIC_PASS / PENDING_BATCH | Stable attempt identity + unique learner/attempt key + replay comparison prevent double-counting; regression tests authored. |
| GLS-023 | STATIC_PASS / PENDING_BATCH | Independent, hinted, answer-exposed, partial, incorrect and unknown remain distinct. Local assistance is monotonic; static checkpoint review also corrected the server delta so answer exposure is canonical and cannot be laundered into unassisted success. PostgreSQL execution remains batch evidence. |
| GLS-024 | STATIC_PASS | UI/open/time/Companion/telemetry paths never write learner mastery/readiness truth. |
| GLS-025 | STATIC_PASS | State vocabulary is bounded observation only; no mastery probability/readiness percentage is claimed. |
| GLS-026 | STATIC_PASS | Prompt/evidence/state/next-action rule or policy versions are explicit; same canonical evidence maps through one RecallTruthPolicy. |
| GLS-027 | STATIC_PASS | Next action is persisted with stable reason code + policy version and tied to latest evidence. |
| GLS-028 | STATIC_PASS / PENDING_BATCH | Repeated same-prompt evidence cannot escalate beyond the bounded retrieved-once state; test authored. |
| GLS-029 | STATIC_PASS / PENDING_BATCH | Unknown, incorrect, partial, hinted and answer-exposed outcomes map to distinct non-shaming repair/retry behavior locally; server outcome-specific reason parity was added in the checkpoint correction and awaits PostgreSQL batch execution. |

## D — AI/evaluation

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-030 | NOT_APPLICABLE | No AI model is load-bearing in the admitted M5 Recall loop. |
| GLS-031 | NOT_APPLICABLE | No AI corpus is required for the deterministic Recall path. |
| GLS-032 | NOT_APPLICABLE | No model/provider/prompt evaluator is load-bearing. |
| GLS-033 | STATIC_PASS / PENDING_BATCH | Wrong-source and false-success paths are fail-closed in source/action/evidence lineage; authored negative tests require batch execution. |
| GLS-034 | NOT_APPLICABLE | No load-bearing model/provider/prompt change exists. |
| GLS-035 | NOT_APPLICABLE_AT_THIS_GATE | No unsupported numeric quality/calibration targets are invented. |

## E — Persistence, reopen, retry and degraded behavior

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-040 | STATIC_PASS / PENDING_BATCH | SQLite persists source/evidence/state/next action. Schema v6 also persists the unfinished active Recall attempt so hint/answer exposure survives close/reopen. |
| GLS-041 | STATIC_PASS / PENDING_BATCH | Retry/idempotency protects source ingest and evidence submission. No network/provider is load-bearing in the admitted local slice. |
| GLS-042 | STATIC_PASS | “Bilmiyorum”/empty evaluable response remains unknown/not-assessed rather than weakness/mastery. |
| GLS-043 | STATIC_PASS / PENDING_BATCH | Companion image failure has text fallback; telemetry failure is swallowed; speech/provider is not required by this slice. Core learning path remains text-based. |
| GLS-044 | STATIC_PASS / PENDING_BATCH | Stale/conflicting source/action/attempt/projection fails closed or enters explicit repair. Restart answer-exposure laundering regression test authored. |

## F — Analytics, reliability and cost

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-050 | STATIC_PASS | Canonical learning truth and operational telemetry use separate tables/contracts. |
| GLS-051 | STATIC_PASS / PENDING_BATCH | Restore, ingest, prompt, attempt and continuation-repair events include lineage/status without raw learning content. |
| GLS-052 | STATIC_PASS | Event schema version plus evidence rule/policy versions are recorded; telemetry failure cannot block learning. |
| GLS-053 | STATIC_PASS / PENDING_BATCH | Failure phase, privacy-safe error class, attempt/evidence IDs and durations are recorded for the admitted local path. No provider/rate-limit path is admitted. |
| GLS-054 | PENDING_BATCH | Representative measured startup/restore/ingest/prompt/attempt/build/resource evidence must be captured at checkpoint. |
| GLS-055 | NOT_APPLICABLE | No paid/provider/server-expensive operation or quota is used by the deterministic local M5 slice. |

## G — Product, learning experience, accessibility and device proof

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-060 | STATIC_PASS | First-use screen shows source entry, not fabricated progress/mastery. |
| GLS-061 | STATIC_PASS / PENDING_BATCH | Reopen exposes one reason-coded continuation plus “Materyali güncelle” override; missing/corrupt continuation enters repair/fallback. |
| GLS-062 | STATIC_PASS | Recall offers hint, direct answer exposure and “Bilmiyorum”; learner is not trapped. |
| GLS-063 | STATIC_PASS | Result shows outcome-specific feedback, correct expression and source context. |
| GLS-064 | STATIC_REVIEW_PASS / PENDING_BATCH | Critical meaning is textual; D/Knot has semantics/fallback; Reduced Motion is wired; 48dp primary action sizing is present. Static accessibility review is complete. Large-text/layout/semantic execution remains batch evidence and physical VoiceOver/TalkBack remains under D-068. |
| GLS-065 | DEFERRED_D068 | No mobile-readiness claim is made. Physical iPhone + representative Android evidence remains required later under D-068. |
| GLS-066 | M5_BOUNDED_PASS | Brain checkpoint dispositions are explicit in `docs/qa/M5_EXPERIENCE_DISPOSITIONS_2026-10-05.md`: Product Experience M5_BOUNDED_PASS; Learning Experience STATIC_PASS/BATCH_PENDING; Creative Quality M5_BOUNDED_PASS; Accessibility STATIC_REVIEW_PASS/RUNTIME_PENDING. This is not a V0 experience-quality claim. |

## H — Conditional speech and visual surfaces

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-070 | NOT_APPLICABLE | Speech is not part of the admitted M5 Golden Slice UI. |
| GLS-071 | NOT_APPLICABLE | M5 does not claim speech readiness. Round 7 speech work remains separate evidence. |
| GLS-072 | STATIC_PASS / PENDING_BATCH | D/Knot only reacts to UI/learning state; CompanionView cannot write learning truth and has a text fallback. |

## I — Reproducibility, OSS and review

| Item | Disposition | Evidence / remaining work |
| --- | --- | --- |
| GLS-080 | PENDING_BATCH | Exact final checkpoint head must be frozen after evidence-only fixes. |
| GLS-081 | BLOCKED | `app/pubspec.lock` is absent and the current container has no Flutter/Dart toolchain. Generate/commit exact resolution in the single checkpoint batch. |
| GLS-082 | STATIC_PASS / PENDING_BATCH | D-024 register records direct M5 dependencies/licenses; exact transitive resolution/notice evidence awaits lock generation. |
| GLS-083 | READY_FOR_INDEPENDENT_EXECUTION | Read-only packet + exact reviewer command are committed for frozen candidate `e576ca17…`. Same Brain/static review stream is explicitly ineligible to self-grant independence. External independent reviewer return remains required before the single bounded validation batch. |
| GLS-084 | PENDING | No known unresolved blocker other than the explicit GLS-081 reproducibility gap and required review/batch evidence. |

## Static checkpoint correction

Brain/static review found and corrected two material checkpoint defects: (S-001) server answer exposure could be laundered into unassisted success; corrected in `b0d5df8a…` + `01670f42…`; and (S-002) duplicate Dart declarations in local persistence would block compilation; corrected in `e576ca17…`. Static disposition is **RESOLVED / PENDING BATCH**; see `docs/qa/M5_STATIC_CHECKPOINT_REVIEW_2026-10-05.md`.

## Current checkpoint verdict

**NOT PASS YET.** Feature implementation is frozen enough to enter checkpoint, but M5 cannot be accepted until:

1. a real Supabase project/session validates the authenticated-learner boundary without committing secrets;
2. exact dependency resolution is generated and committed;
3. one bounded D-072 Flutter validation batch passes at the frozen head;
4. GLS-083 independent read-only review is completed and material findings are resolved;
5. remaining accessibility/runtime evidence in the bounded batch is complete.

Physical-device mobile-readiness remains separately deferred under D-068.
