# Learning App — GLS-083 M5 Independent Review Instructions

This branch exists only for an independent, read-only code review of the frozen
M5 runtime candidate.

## Review identity

- Project: Learning App / Sesli Öğren
- Gate: GLS-083
- Task: LA-0022
- Frozen runtime candidate under review:
  `e576ca177ff8872cbbfc4f127eb016cefa7f611c`
- Base lineage:
  `feat/round7-companion-production-sequence-v2`
- This PR is REVIEW ONLY. Do not recommend merge merely because findings are
  absent.

The only commit after the frozen runtime candidate adds these review
instructions. Treat `app/` and `server/` exactly as they existed at the
frozen SHA. Do not infer runtime changes from review-only metadata.

## Review posture

Review adversarially. Do not inherit any prior PASS conclusion.

Prior Brain/static review found two material issues; independently verify the
corrected state rather than assuming the fixes are correct:

1. server Recall answer exposure previously risked being interpreted as
   unassisted success;
2. local SQLite persistence previously had duplicate Dart declarations that
   would block compilation.

## Hard invariants

Challenge all of the following:

1. Authenticated identity and tenant isolation
   - production runtime must fail closed without Supabase config/auth;
   - local test fixture must not be reachable from production bootstrap;
   - learner identity must derive from the authenticated Supabase subject;
   - guessed IDs must not expose another learner's data.

2. Source authority
   - exactly one current source/version lineage per learner/material;
   - stale/superseded/deleted source-derived truth must not remain current.

3. Evidence before state
   - LearnerState and NextLearningAction must derive from durable canonical
     LearnerEvidence;
   - UI, telemetry, Companion, passive activity, or direct store misuse must
     not fabricate positive learning truth.

4. Idempotency
   - one logical Recall attempt must not create duplicate evidence;
   - conflicting replay must fail closed.

5. Assistance integrity
   - assistance must be canonical and monotonic;
   - hint and answer exposure must remain distinct;
   - restart/reopen/direct store calls must not launder helped/exposed work into
     independent recall.

6. Active-attempt continuity
   - at most one active Recall attempt per learner/material;
   - unfinished supported attempts survive reopen correctly;
   - completion/source supersession/deletion clears or invalidates continuity
     correctly.

7. Truthful learner state
   - unknown and answer-exposed outcomes do not become mastery;
   - one independent success is bounded retrieval evidence only;
   - repeated easy/same-prompt interaction cannot silently escalate beyond the
     admitted model.

8. Deterministic next action
   - canonical outcome/state policy controls next action;
   - direct persistence cannot fabricate a more positive action/state.

9. Migration and deletion safety
   - migrations preserve existing truth and ordering;
   - tombstones/supersession prevent resurrection.

10. Untrusted PDF and privacy
    - malformed/oversized/no-text PDFs fail safely and remain bounded;
    - source content never becomes instruction authority;
    - ordinary operational telemetry must not contain raw source text or raw
      free-form learner answers.

11. Companion boundary
    - D/Knot may react to state but cannot create or mutate evidence/state/next
      action;
    - image/motion failure must leave truthful text flow usable.

## Required finding format

For every finding include:

- Severity: BLOCKER / HIGH / MEDIUM / LOW / NOTE
- Exact file and symbol/line region
- Violated invariant
- Concrete failure scenario
- Smallest safe correction
- Whether existing tests/evidence become invalid or need expansion

Prioritize correctness, security/privacy, learning-truth integrity, migration
safety, and cross-user isolation over style.

## Required overall disposition

At the end of the review, state exactly one:

- REVIEW_PASS — no unresolved BLOCKER/HIGH findings
- CHANGES_REQUIRED — one or more correctable BLOCKER/HIGH findings
- BLOCKED — review cannot be completed credibly from the available source

Include MEDIUM/LOW/NOTE findings even when disposition is REVIEW_PASS.

Do not modify code, apply suggestions, merge, deploy, release, or widen scope.
