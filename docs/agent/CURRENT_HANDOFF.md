# CURRENT HANDOFF

This file is the mission-level executable contract. Brain owns it and the
Engineer mirrors it. It is **not** a message log: incremental Brain
instructions arrive as [`commands/CMD-####.md`](commands/), and Engineer
responses go to [`returns/RET-####.md`](returns/) ([`README.md`](README.md)).

## Active

| Field | Value |
| --- | --- |
| Handoff | **CLAUDE_HANDOFF_001 — V0 Architecture Spike** |
| State | **M4 ACCEPTED / REPO CLOSURE PROJECTION PENDING**. Brain Review 004 issued **ARCHITECTURE_PROOF_PASS / GO_ADAPT** for immutable reviewed architecture head `0327d2e5b854df1c9923c65ed88f77151cfe9eed`. [RET-0005](returns/RET-0005.md) remains the accepted engineering evidence. [CMD-0014](commands/CMD-0014.md) is the current unread closure/projection command. It must reconcile repo-local state without reopening architecture or admitting M5. |
| Authority reading | CLAUDE_HANDOFF_001 is the M4 mission container but is **partially superseded** and now accepted by Review 004. Read order for closure: CURRENT_EXECUTION_STATE → CLAUDE_HANDOFF_001 → HANDOFF_COMMAND_AUTHORITY_AUDIT_001 → CMD-0004 … CMD-0014 → D-062 compatibility overlay. D-061 remains PROPOSED and non-executable. |
| Executor | Claude (Primary Engineer) |
| Milestone | M1 — Architecture Proof (Drive lifecycle stage "M4") |
| Tasks | LA-0009 … LA-0017 (see [`TASKS.md`](../../TASKS.md)). These run as one Continuous Engineering Mission in dependency order. |
| Branch | `spike/v0-architecture-proof`, derived from reviewed bootstrap head `433c26cf5fa75a37b66b1f74dd6a133ae4d3407a` |
| Delivery | Draft PR [#2](https://github.com/Jay-prodesign/sesli-ogren/pull/2), stacked on `chore/repository-bootstrap`; nothing is merged. Review 004 accepted architecture at `0327d2e5…`. Later Brain/closure commits (including the CMD-0014 command commit) are control-plane projection only and must be reported separately from the reviewed architecture head. |
| Evidence | [`ENGINEER_RETURN.md`](ENGINEER_RETURN.md) (consolidated), [`returns/`](returns/) |
| Exit gate | **MET at architecture level:** Brain Review 004 = ARCHITECTURE_PROOF_PASS / GO_ADAPT on `0327d2e5…`. Remaining work in this handoff is repo-local closure projection under CMD-0014 only. It must end with M5 still NOT_EXECUTABLE. |

### Mission summary (non-private)

Prove or falsify the V0 implementation path. The path under test is a Flutter
client, a Supabase/Postgres backend with a MoonlighC-derived product shell,
layered permissive reuse (D-024/D-025), one authoritative Learning App model,
and a provider-neutral AI capability seam. The proof covers:

- canonical model mapping;
- one authenticated material → Summary Artifact flow;
- tenant/RLS isolation;
- GenerationJob idempotency and lineage;
- the reuse/provenance matrix;
- measured adaptation burden.

Every material decision is held to D-029 (AGENTS.md §14). The following are
out of scope: full V0 or M5, V1 learning semantics, payments/billing, ads,
an operator console, TTS or any speech implementation, companion/map/product UI,
production OCR, deployment, and paid providers. The base Learning Engine stays
voice-optional (D-042). Sesli Öğren speech is product-local behind a replaceable
boundary (D-062); M4 assesses compatibility only.

### Governing references (Drive, by title only)

- CURRENT_EXECUTION_STATE — Learning App
- CLAUDE_HANDOFF_001 — V0 Architecture Spike — Learning App
- M4_ARCHITECTURE_PROOF_TASK_ADMISSION_001 — Learning App
- M4_ARCHITECTURE_PROOF_BRAIN_REVIEW_CHECKLIST_v0.1 — Learning App
- BRAIN_COMMAND_0002 … BRAIN_COMMAND_0014 — Learning App (transcribed as CMD-0002 … CMD-0014)
- HANDOFF_COMMAND_AUTHORITY_AUDIT_001 — Learning App (per-command classification)
- M4_ARCHITECTURE_PROOF_BRAIN_REVIEW_004 — ARCHITECTURE_PROOF_PASS; M4_ARCHITECTURE_PROOF_BRAIN_REVIEW_003 — historical CHANGES_REQUIRED; M4_ARCHITECTURE_PROOF_CORRECTION_MAP_001 (supporting, partially superseded) — Learning App
- DECISION_LOG — Learning App: D-015, D-024, D-025 (+ technical refinements 1 and 2), D-026 … D-029, D-031, D-034, D-037, D-042, D-043, D-053, D-054, D-062
- ENGINEERING & PRODUCT QUALITY CONSTITUTION — Learning App (D-029)
- V0_CANONICAL_DATA_CAPABILITY_CONTRACTS_v0.1; V0_PRODUCT_SCOPE_v2.0 (current; v1.0 is no longer product authority); V0_PRIVACY_SECURITY_RIGHTS_CONTRACT_v0.1; V0_ENTITLEMENT_MONETIZATION_CONTRACT_v0.1 — Learning App

## Completed

| Handoff | Outcome |
| --- | --- |
| CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap | **BOOTSTRAP_PASS** (M3_BOOTSTRAP_BRAIN_REVIEW_002, reviewed head `433c26c`). PR #1 is draft and unmerged; merging it is a Product Owner action. |

## Staged

| Field | Value |
| --- | --- |
| Handoff | **M5_GOLDEN_LEARNING_SLICE_HANDOFF_NOT_ISSUED**: no current-shape M5 handoff has been issued |
| State | **NOT_EXECUTABLE**. M4 Architecture Proof PASS is met, but M5 remains closed pending the controlling Product/Visual PASS, applicable Round 7/runtime/device evidence, fresh-read reconciliation, and a new explicit Brain M5 admission/handoff. The prepared Golden Learning Slice acceptance contract does not itself grant executability. |
| Rule | No V0 feature implementation may start from this closure command. Admission requires a new explicit M5 command/handoff with `Executability change` and all controlling gate evidence (AGENTS.md §13.5). |
