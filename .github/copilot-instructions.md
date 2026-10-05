# Learning App — GLS-083 Independent Review Instructions

This branch exists only for an independent, read-only code review of the frozen
M5 runtime candidate.

## Review identity

- Project: Learning App / Sesli Öğren
- Gate: GLS-083
- Task: LA-0022
- Frozen runtime candidate under review:
  `64579d48bcf9c33f4c709927a0e453349efb7c5b`
- Base lineage:
  `feat/round7-companion-production-sequence-v2`
- This PR is REVIEW ONLY. Do not recommend merge merely because findings are absent.

The only commit after the frozen runtime candidate adds these review
instructions and is marked `[skip ci]`. Treat `app/` and
`server/db/migrations/` exactly as they existed at the frozen SHA.

## Review posture

Review adversarially and do not inherit prior PASS conclusions.

Prior Brain/static/synthetic review found three material issues. Independently
verify the corrected state rather than assuming the fixes are correct:

1. S-001 — server Recall answer exposure could be laundered into unassisted
   success;
2. S-002 — duplicate Dart canonical-transition declarations would block
   compilation;
3. S-003 — server answer-exposure semantics were being written under stale v1
   evidence/state rule labels; historical v1 evidence must remain historical,
   while new evidence/state must use v2 semantics.

## Hard invariants

1. Authenticated identity and tenant isolation.
2. One current authoritative source/version lineage.
3. Evidence-before-state and evidence-before-next-action.
4. Idempotent logical attempts; conflicting replay fails closed.
5. Assistance is canonical and monotonic; answer exposure never becomes
   independent success.
6. Active-attempt continuity is durable and source-bound.
7. Learner state remains bounded and truthful; one success is not mastery.
8. Next action is deterministic and versioned from canonical evidence.
9. Historical rule-version provenance is preserved; changed semantics use a
   new version label.
10. Supersession/deletion/migration cannot resurrect stale truth.
11. Untrusted PDFs remain bounded/fail-closed.
12. Operational telemetry excludes raw source/free-form answer content.
13. D/Knot reacts to truth but cannot create truth.

## Required finding format

For every finding include:
- severity: BLOCKER / HIGH / MEDIUM / LOW / NOTE;
- exact file + symbol/line region;
- violated invariant / GLS item;
- concrete failure scenario;
- smallest safe correction;
- tests/evidence invalidated or needing expansion.

Do not fix findings in this review workspace.

## Required overall disposition

Return exactly one:
- REVIEW_PASS — no unresolved BLOCKER/HIGH;
- CHANGES_REQUIRED — one or more correctable BLOCKER/HIGH;
- BLOCKED — review cannot be completed credibly.

Include MEDIUM/LOW/NOTE findings even if disposition is REVIEW_PASS.
Do not merge, deploy, release, or widen scope.
