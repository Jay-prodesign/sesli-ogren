# M5 GLS-083 Independent Read-Only Review Packet

## Review identity

- Project: Learning App / Sesli Öğren
- Mission: M5 Golden Learning Slice
- Branch: `feat/m5-golden-learning-slice`
- Frozen runtime implementation candidate: `01670f42029ef228706c4a772594102e5656ebdf`
- Later commits are checkpoint/control-plane documentation only unless the packet is explicitly refreshed again.
- Governing acceptance: `M5_GOLDEN_LEARNING_SLICE_ACCEPTANCE_CONTRACT_v0.1`
- Review trigger: GLS-083
- Reviewer mode: **read-only**
- Routine GitHub Actions: **OFF under D-072**

The reviewer must evaluate the code independently. This packet is a map, not a PASS claim.

Static checkpoint review S-001 previously found that the server path collapsed answer exposure into hint/no-help semantics. That defect was corrected in `b0d5df8a…` + `01670f42…`. The independent reviewer must verify the correction rather than inheriting the prior review conclusion.

## Why independent review is required

M5 materially changes:
- local persistence and schema migrations;
- source authority / supersession / deletion semantics;
- learner-evidence idempotency;
- deterministic learner-state and next-action derivation;
- assistance semantics;
- active Recall attempt continuity across close/reopen;
- malformed/untrusted PDF handling;
- operational telemetry boundaries.

A BLOCKER or HIGH data-integrity/security finding prevents M5 PASS until remediated or dispositioned by the controlling authority.

## Critical files

### Source authority and persistence
- `app/lib/src/domain/learning_contracts.dart`
- `app/lib/src/data/source_store.dart`
- `app/lib/src/data/source_ingest_service.dart`
- `app/lib/src/data/pdf_text_extractor.dart`
- `app/lib/src/data/sqlite_source_store.dart`

### Learning truth
- `app/lib/src/domain/learning_truth.dart`
- `app/lib/src/data/learning_truth_store.dart`
- `app/lib/src/learning/recall_learning_service.dart`
- `server/db/migrations/0003_recall_learning_truth.sql`
- `server/db/migrations/0004_server_authoritative_recall_assistance.sql`
- `server/db/tests/40_recall_learning_truth.sql`

### Operational separation
- `app/lib/src/domain/operational_event.dart`
- `app/lib/src/data/operational_telemetry.dart`

### Authentication / runtime / continuity / Companion
- `app/lib/src/auth/supabase_learner_auth.dart`
- `app/lib/src/app/app_runtime.dart`
- `app/lib/src/app/learning_slice_screen.dart`
- `app/lib/src/app/companion_view.dart`
- `app/lib/src/app/sesli_ogren_app.dart`

### High-value regression tests
- `app/test/source_ingest_service_test.dart`
- `app/test/pdf_text_extractor_test.dart`
- `app/test/recall_learning_service_test.dart`
- `app/test/recall_support_upgrade_test.dart`
- `app/test/app_smoke_test.dart`

### Provenance / checkpoint
- `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`
- `docs/qa/M5_CHECKPOINT_ACCEPTANCE.md`
- `docs/exec-plans/LA-0022.md`

## Hard invariants to challenge

1. **Single source authority**
   - one learner/material has one current authoritative SourceVersion;
   - derived content/action/evidence/state/next-action cannot silently point at a stale source.

2. **Authenticated identity + cross-user isolation**
   - production `AppRuntime` cannot open from a hard-coded/local learner fixture;
   - runtime learner ID must derive from the authenticated Supabase subject;
   - missing auth config/session fails closed before learner data opens;
   - no service-role/secret key is present in client/repository.

3. **Cross-user isolation**
   - every source/action/support/evidence/state/next-action/telemetry read or mutation is learner-scoped;
   - guessed IDs must not cross learner boundaries.

3. **Evidence-before-state**
   - no state/next-action write may exist without durable canonical LearnerEvidence;
   - UI/Companion/telemetry/passive actions never create learning truth.

4. **Idempotency**
   - replaying the same logical attempt cannot add a second evidence row or transition;
   - conflicting replay fails closed.

5. **Assistance integrity**
   - hint and answer exposure are canonical persisted history, not client claims;
   - assistance is monotonic: none → hint → answerExposed;
   - client/store bypass cannot downgrade assistance;
   - restart cannot turn a helped/exposed attempt into independent retrieval.

6. **Active-attempt continuity**
   - at most one active Recall attempt exists per learner/material;
   - unfinished attempt survives reopen;
   - successful evidence closes it;
   - source supersession/deletion clears it;
   - stale action/attempt mismatch fails closed.

7. **Truthful state**
   - unknown / answer-exposed does not become fabricated weakness/mastery;
   - a single success becomes only bounded `retrievedOnce`, not mastery/readiness probability;
   - repeated easy/same prompt cannot indefinitely escalate state.

8. **Deterministic next action**
   - state and next action derive from canonical outcome through one versioned policy;
   - direct persistence of fabricated positive state/next action is rejected.

9. **Deletion / supersession**
   - deleted material leaves a non-resurrectable tombstone;
   - raw source payload / extracted content is purged or invalidated as designed;
   - active projections cannot survive as current truth.

10. **Migration safety**
    - v1/v2 historical local DBs upgrade without silent reset;
    - v5→v6 adds active-attempt continuity without destroying prior local data;
    - migration order satisfies foreign-key dependencies.

11. **Untrusted PDF**
    - malformed/oversized/no-text PDF fails safely;
    - parser limits are bounded;
    - PDF/source content cannot become instruction authority.

12. **Privacy-safe telemetry**
    - operational analytics contain lineage/status/version/duration/error class only;
    - no raw source text or raw free-text learner answer is stored in ordinary operational events;
    - telemetry failure cannot block or mutate learning truth.

13. **Companion boundary**
    - D/Knot reacts to product state but cannot write evidence/state/next-action;
    - image/motion failure leaves truthful textual learning flow usable.

## Reviewer questions

For each finding, provide:
- severity: BLOCKER / HIGH / MEDIUM / LOW / NOTE;
- exact file + symbol/line region;
- violated invariant / GLS item;
- concrete failure scenario;
- smallest safe correction;
- whether the finding invalidates already-authored tests/evidence.

Explicitly answer:
1. Can assistance be laundered or downgraded by any direct store/service call?
2. Can restart/reopen create a new attempt while prior hint/answer exposure remains semantically relevant?
3. Can evidence be inserted without the current authoritative source/action/active-attempt lineage?
4. Can a duplicate or conflicting attempt double-count evidence?
5. Can a stale/deleted/superseded source retain a usable state or continuation?
6. Can User B infer/read/mutate User A truth by guessed IDs?
7. Can direct store calls fabricate a more positive LearnerState or NextLearningAction than canonical policy permits?
8. Can migrations silently reset or strand truth?
9. Can operational telemetry capture raw source/answer content?
10. Is there any second competing source/evidence/state authority?

## Required reviewer return

Use exactly one disposition:
- **REVIEW_PASS** — no unresolved BLOCKER/HIGH findings;
- **CHANGES_REQUIRED** — correctable BLOCKER/HIGH findings exist;
- **BLOCKED** — review cannot be completed credibly because required evidence/source is unavailable.

Include all findings, not only the highest severity. Do not merge, run release actions, change product scope or mutate the branch.


## Authentication-specific reviewer questions

- Does any production path still open `AppRuntime` with `localM5LearnerFixture`?
- Can missing/failed Supabase authentication fall through to a local learner identity?
- Are only client-safe project URL/publishable-key values accepted at the Flutter boundary, with no service-role secret?
- Does changing authenticated user result in a different learner-scoped local truth namespace?
- Is anonymous authentication acceptable only as the bounded M5 account bootstrap, without being mistaken for final account/login UX?
