# CURRENT HANDOFF

This file is the mission-level executable contract. Brain owns it and the
Engineer mirrors it. It is **not** a message log: incremental Brain
instructions arrive as [`commands/CMD-####.md`](commands/), and Engineer
responses go to [`returns/RET-####.md`](returns/) ([`README.md`](README.md)).

## Active

| Field | Value |
| --- | --- |
| Handoff | **CLAUDE_HANDOFF_001 — V0 Architecture Spike** |
| State | **ACTIVE / AWAITING_BRAIN_REVIEW (Review 003 correction returned)**. Brain Review 003 (reviewed head `9fb2d9b`) was **CHANGES_REQUIRED**, with GO_ADAPT supported. The bounded corrections [CMD-0004](commands/CMD-0004.md) … [CMD-0013](commands/CMD-0013.md) are complete and returned cumulatively in [RET-0005](returns/RET-0005.md). ARCHITECTURE_PROOF_PASS is **not** claimed. The mission was admitted by [CMD-0002](commands/CMD-0002.md) (`Executability change: CLAUDE_HANDOFF_001 -> READY`, gate evidence M3_BOOTSTRAP_BRAIN_REVIEW_002 BOOTSTRAP_PASS), with the D-029 overlay from [CMD-0003](commands/CMD-0003.md). The original return is [RET-0004](returns/RET-0004.md). |
| Authority reading | CLAUDE_HANDOFF_001 is the mission container but is **partially superseded**, so it is not read standalone. Read order: CURRENT_EXECUTION_STATE → CLAUDE_HANDOFF_001 → HANDOFF_COMMAND_AUTHORITY_AUDIT_001 → CMD-0004 … CMD-0013 (per-command classification) → D-062 compatibility overlay. D-061 is PROPOSED and non-executable. |
| Executor | Claude (Primary Engineer) |
| Milestone | M1 — Architecture Proof (Drive lifecycle stage "M4") |
| Tasks | LA-0009 … LA-0017 (see [`TASKS.md`](../../TASKS.md)). These run as one Continuous Engineering Mission in dependency order. |
| Branch | `spike/v0-architecture-proof`, derived from reviewed bootstrap head `433c26cf5fa75a37b66b1f74dd6a133ae4d3407a` |
| Delivery | Draft PR [#2](https://github.com/Jay-prodesign/sesli-ogren/pull/2), stacked on `chore/repository-bootstrap`. Nothing is merged. PR #1 stays untouched as the reviewed bootstrap evidence. The final head is bound externally to the PR #2 head (CMD-0009: `PR_HEAD_AT_REVIEW` / `GITHUB_PR_HEAD`). |
| Evidence | [`ENGINEER_RETURN.md`](ENGINEER_RETURN.md) (consolidated), [`returns/`](returns/) |
| Exit gate | Brain resolves the PR #2 head, checks `bootstrap-validation`, `spike-proof` and `flutter-proof` on that exact SHA, and reviews RET-0005 → `ARCHITECTURE_PROOF_PASS` (GO_ADAPT) or `CHANGES_REQUIRED`. |

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
- BRAIN_COMMAND_0002 … BRAIN_COMMAND_0013 — Learning App (transcribed as CMD-0002 … CMD-0013)
- HANDOFF_COMMAND_AUTHORITY_AUDIT_001 — Learning App (per-command classification)
- M4_ARCHITECTURE_PROOF_BRAIN_REVIEW_003 — CHANGES_REQUIRED; M4_ARCHITECTURE_PROOF_CORRECTION_MAP_001 (supporting, partially superseded) — Learning App
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
| Handoff | **VS-001_HANDOFF_NOT_ISSUED**: the VS-001 Golden Vertical Slice handoff has not been issued yet |
| State | **NOT_EXECUTABLE**. It needs Brain ARCHITECTURE_PROOF_PASS and an explicit post-M4 admission (CMD-0013). M5 stays closed. |
| Rule | No V0 feature implementation may start from this mission. Admission requires an explicit command with `Executability change` and PASS gate evidence (AGENTS.md §13.5). |
