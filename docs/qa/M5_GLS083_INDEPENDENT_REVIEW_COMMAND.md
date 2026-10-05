# M5 GLS-083 Independent Reviewer Command

## Target

- Project: Learning App / Sesli Öğren
- Task: LA-0022
- Review gate: GLS-083
- Branch: `feat/m5-golden-learning-slice`
- **Frozen runtime candidate:** `e576ca177ff8872cbbfc4f127eb016cefa7f611c`
- Reviewer mode: **READ-ONLY**
- Mutation authority: **NONE**
- Merge/release/deploy authority: **NONE**

Later branch commits may contain documentation/control-plane changes and bounded M5 validation tooling only. Review `app/` and `server/` runtime code exactly as it existed at the frozen candidate SHA. Validation helper scripts are not evidence of runtime PASS and must not widen review scope.

## Independent-review requirement

The reviewer must be a separate reviewer context from the Brain/static review
that authored/fixed S-001 and S-002. Do not inherit the prior PASS conclusion.

Known prior findings to verify independently:

- S-001: server Recall answer exposure could be laundered into unassisted
  success. Correction lineage:
  `b0d5df8adc0f8155946cc308f280651022ee9a13` +
  `01670f42029ef228706c4a772594102e5656ebdf`.
- S-002: duplicate Dart canonical-transition declarations in
  `sqlite_source_store.dart` would block compilation. Correction:
  `e576ca177ff8872cbbfc4f127eb016cefa7f611c`.
- S-003: server answer-exposure semantics were written under stale v1
  evidence/state rule labels. Correction:
  `64579d48bcf9c33f4c709927a0e453349efb7c5b`.

These are review targets, not accepted facts.

## Required reads

Read first:

1. `AGENTS.md`
2. `docs/agent/EXECUTION_STATE.json`
3. `docs/exec-plans/LA-0022.md`
4. `docs/qa/M5_GLS083_REVIEW_PACKET.md`
5. `docs/qa/M5_CHECKPOINT_ACCEPTANCE.md`

Then inspect the critical runtime/test surfaces listed by
`M5_GLS083_REVIEW_PACKET.md` at the frozen runtime candidate SHA.

## Review priorities

Challenge, rather than merely restate, these invariants:

1. authenticated learner identity and cross-user isolation;
2. single authoritative source/version lineage;
3. evidence-before-state and evidence-before-next-action;
4. idempotent attempts and conflicting-replay fail-closed behavior;
5. assistance monotonicity and answer-exposure integrity;
6. durable active-attempt continuity across reopen;
7. truthful learner-state semantics;
8. deterministic/versioned next-action derivation;
9. deletion/supersession non-resurrection;
10. migration safety and ordering;
11. malformed/untrusted PDF limits;
12. privacy-safe telemetry;
13. Companion cannot create learning truth.

Explicitly try to find a path that:

- turns helped or answer-exposed Recall into independent success;
- creates evidence without current authoritative source/action/attempt lineage;
- double-counts one logical attempt;
- lets stale/deleted source truth remain usable;
- allows one authenticated learner to reach another learner's truth;
- fabricates a more positive state/next action through direct persistence calls;
- captures raw source/free-form answer in ordinary operational telemetry;
- silently resets/strands truth during migration.

## Finding format

For every finding include:

- severity: BLOCKER / HIGH / MEDIUM / LOW / NOTE;
- exact file + symbol/line region;
- violated invariant / GLS item;
- concrete failure scenario;
- smallest safe correction;
- whether authored tests/evidence become invalid or need expansion.

Do not fix findings in the review workspace.

## Required disposition

Return exactly one:

- `REVIEW_PASS` — no unresolved BLOCKER/HIGH;
- `CHANGES_REQUIRED` — one or more correctable BLOCKER/HIGH findings;
- `BLOCKED` — review cannot be completed credibly because required
  source/evidence is unavailable.

Include all findings even when the final disposition is REVIEW_PASS.

## Return artifact

Preferred durable return:
`docs/qa/M5_GLS083_INDEPENDENT_REVIEW_RETURN.md`

The return must identify:

- reviewer/context;
- exact frozen runtime SHA reviewed;
- disposition;
- findings;
- files inspected;
- limitations / unexecuted checks;
- required next action.

Do not mutate runtime code, current task scope, product decisions, branch
history, PR state, CI policy, or release state.
