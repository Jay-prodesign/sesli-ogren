# M5 ENGINEER RETURN — LA-0019 CLOSED / LA-0020 ACTIVE

## LA-0019 disposition

**DONE (implementation), with milestone runtime batch pending under D-072.**

Implemented:
- authoritative Material → immutable SourceVersion → ExtractedContent separation;
- exact-byte source identity for pasted text and PDF;
- bounded pasted-text and PDF input limits;
- real PDF extraction path with page provenance anchors and explicit OCR-not-admitted failure;
- learner-scoped SQLite persistence;
- retry idempotency, stale/superseded-source fail-closed behavior;
- deletion tombstone + raw payload purge + extracted-content purge;
- same material ID cannot silently resurrect after deletion;
- real two-page PDF fixture/reopen test authored;
- D-024 dependency/provenance entries for crypto, sqflite, sqflite_common_ffi and pdfrx.

Static/contract evidence:
- pdfrx 2.6.1 requirements align with repo Flutter 3.47.5 and iOS deployment target 15.0;
- pdfrx direct-engine initialization is explicitly awaited;
- sqflite DatabaseFactory/OpenDatabaseOptions/in-memory test usage matches upstream API;
- SQLite tombstone/purge schema sequence was checked deterministically outside GitHub Actions.

Pending at M5 checkpoint:
- one bounded Flutter pub resolution/format/analyze/test/Android+iOS build batch under D-072;
- GLS-083 independent read-only review of persistence/idempotency.

## Current cursor

**LA-0020 — IN_PROGRESS.** Implement one meaningful source-grounded active learning action, durable LearnerEvidence, minimal deterministic versioned LearnerState and explainable next action. Passive activity cannot become mastery/readiness truth.

---

# M5 ENGINEER RETURN — LA-0018 CLOSED / LA-0019 ACTIVE

## LA-0018 disposition

**DONE.** Production `app/` exists independently from proof UI; D/Knot is the only production Companion asset; accepted Architecture Proof substrate is selectively imported without stale control-plane overwrite; the app has a small canonical source/persistence seam; PR #10 exact-head `7107f2e4d5eb5a07ac6e066b2cb56bbfcda29606` passed bootstrap-validation, spike-proof, flutter-proof and m5-app (format, analyze, tests, Android profile APK, iOS profile no-codesign).

## Current cursor

**LA-0019 — IN_PROGRESS.** Implement authoritative real PDF/plain-text ingest, immutable source/version/provenance identity, retry/idempotency, tenant isolation and supersession/deletion semantics. No production credentials, deploy/release, OCR, broad library UI or V1 learner-model work is admitted.

---

# ENGINEER RETURN — CLAUDE_HANDOFF_000 — Repository & Agent Bootstrap (correction round 1)

## Verdict

**BOOTSTRAP_READY_FOR_BRAIN_REVIEW**. Brain Review 001 (CHANGES_REQUIRED)
corrections A–G and the D-026 addendum are addressed on the existing draft PR #1.
Command CMD-0001 is answered by [RET-0001](returns/RET-0001.md). Execution state:
`AWAITING_BRAIN_REVIEW`. Bridge: **AUTO_AGENT_BRIDGE_BLOCKED** (Founder
authorization gates; not a bootstrap-review blocker). CLAUDE_HANDOFF_001 remains
**NOT_EXECUTABLE**.

## Repository

| Field | Value |
| --- | --- |
| Repository | https://github.com/Jay-prodesign/sesli-ogren (owner `Jay-prodesign`, PUBLIC per D-023) |
| Default branch | `main` |
| Base SHA | `52616b4b4f018ece72d3ee1de4949875bb144e9a` (`main`, untouched) |
| Branch | `chore/repository-bootstrap` |
| Previously reviewed head | `97e9040acf6a668f279a4aa1fedcd9bbbce810e2` (Brain Review 001) |
| Correction content head | `1ad2c8a3e4cfc34bf5ea85b3d7cfff7b4d9292e5` |
| Final head | The reconciliation commit on top of the content head. Its exact SHA and CI run are in PR #1 and the engineer's final report (a commit cannot contain its own SHA). |
| Draft PR | [#1](https://github.com/Jay-prodesign/sesli-ogren/pull/1): draft, open, unmerged, base `main`. No new PR was created. |

## Pre-flight (LA-0001)

- `origin` = `https://github.com/Jay-prodesign/sesli-ogren`. Branch checked out at `97e9040` = PR #1 head, clean tree, `origin/main` = base SHA.
- PR #1 metadata: draft, open, not merged, mergeable `clean`. The only workflow was `bootstrap-validation`.
- **Drive: AVAILABLE.** Fresh-read by title: CURRENT_EXECUTION_STATE, CLAUDE_HANDOFF_000, M3_BOOTSTRAP_BRAIN_REVIEW_001, M3_REPOSITORY_BOOTSTRAP_ACCEPTANCE_CHECKLIST_v0.1, DECISION_LOG (D-024/D-025/D-026), PRE_BOOTSTRAP_PRODUCT_READINESS_AND_MASTER_SEQUENCE_v1.0, ENGINEERING_EXECUTION_PROTOCOL. No Drive content was copied into this repository. The previous "Incompatible auth server" error did not recur.

## Brain Review 001 corrections

| Item | Resolution | Files |
| --- | --- | --- |
| A — D-024 reuse control | Register template with every required field, reuse-class and audit vocabularies, and a "rejected approved candidates" log. AGENTS.md §12 has the exact five classes, the no-ownership-optics rewrite rule, the prohibition on unapproved dependencies, and reuse-return duties. Validator enforces all of it. | `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`, `docs/provenance/README.md`, `AGENTS.md` |
| B — D-026 command bus (LA-0008) | CMD/RET conventions, role separation, acknowledgement / answer / refusal / recovery semantics, state pointers + ledger, executability guard, CMD-0001 / RET-0001 | `docs/agent/commands/*`, `docs/agent/returns/*`, `docs/agent/README.md`, `EXECUTION_STATE.json`, `AGENTS.md` §13, `CLAUDE.md` |
| C — Claude invocation bridge | Official `anthropics/claude-code-action@v1` workflow: wake-up only and inert until activation. Status **AUTO_AGENT_BRIDGE_BLOCKED** (gates below). | `.github/workflows/claude-bridge.yml` |
| D — Whole-V0 skeleton | M1 Architecture Proof · M2 VS-001 Golden Vertical Slice · M3 V0 Implementation Tranches · M4 Beta / Validation · M5 Brand/Name Freeze & Release Readiness · M6 Controlled Public V0 Release · M7 Post-Launch Learning / V1 Admission. Each is PLANNED / NOT_EXECUTABLE with sprints and no tasks. | `TASKS.md` |
| E — Exec-plan completeness | LA-0001 … LA-0008 each carry Objective, Authoritative source references, In scope, Out of scope, Dependencies, Acceptance criteria, Required tests / evidence, Rollback / migration notes, Escalation conditions, and Expected return. | `docs/exec-plans/*` |
| F — Minimal `.claude/rules/` | Three Markdown rule files that restate AGENTS.md. The validator forbids anything else under `.claude/`. | `.claude/rules/*` |
| G — Validation / reconciliation | Validator extended; 35-test negative suite added to CI; all control files reconciled | `scripts/*`, `.github/workflows/bootstrap-validation.yml` |

## Files changed since reviewed head `97e9040` (31)

- **Added (11):** `.claude/rules/README.md`, `.claude/rules/control-plane.md`, `.claude/rules/public-repo-safety.md`, `.github/workflows/claude-bridge.yml`, `docs/agent/commands/README.md`, `docs/agent/commands/CMD-0001.md`, `docs/agent/returns/README.md`, `docs/agent/returns/RET-0001.md`, `docs/exec-plans/LA-0008.md`, `docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`, `scripts/test_validate_bootstrap.py`
- **Modified (20):** `.github/workflows/bootstrap-validation.yml`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `TASKS.md`, `docs/agent/CURRENT_HANDOFF.md`, `docs/agent/ENGINEER_RETURN.md`, `docs/agent/EXECUTION_STATE.json`, `docs/agent/README.md`, `docs/exec-plans/README.md`, `docs/exec-plans/LA-0001.md` … `LA-0007.md`, `docs/provenance/README.md`, `scripts/README.md`, `scripts/validate_bootstrap.py`

## Task status (Milestone M0)

| Task | Title | Status |
| --- | --- | --- |
| LA-0001 | Pre-flight verification and canonical repository identity | AWAITING_BRAIN_REVIEW |
| LA-0002 | Repository hygiene baseline | AWAITING_BRAIN_REVIEW |
| LA-0003 | Agent operating contracts | AWAITING_BRAIN_REVIEW |
| LA-0004 | Task map and execution plans | AWAITING_BRAIN_REVIEW |
| LA-0005 | Agent control files and documentation skeleton | AWAITING_BRAIN_REVIEW |
| LA-0006 | Bootstrap validation script and CI workflow | AWAITING_BRAIN_REVIEW |
| LA-0007 | Draft PR delivery and state/evidence reconciliation | AWAITING_BRAIN_REVIEW |
| LA-0008 | Brain↔Engineer Command Bus & Automated Claude Invocation Bridge | AWAITING_BRAIN_REVIEW |

The next unallocated ID is LA-0009. M1–M7 are PLANNED / NOT_EXECUTABLE. `TASKS.md`,
the plan headers, `EXECUTION_STATE.json` `tasks`, and `CURRENT_HANDOFF.md` agree
(validator-enforced).

## Command / return bus

| Pointer | Value |
| --- | --- |
| `last_command_id` | CMD-0001 |
| `last_acknowledged_command_id` | CMD-0001 |
| `last_return_id` | RET-0001 |
| `command_processing_status` | ANSWERED |
| `command_ledger` | `CMD-0001 → ANSWERED, RET-0001` |

The next Brain command should be **CMD-0002**, and the next Engineer return **RET-0002**.

## Commands, checks, results

| Command / check | Result |
| --- | --- |
| `python3 scripts/validate_bootstrap.py` | `OK: 1346 checks passed across 38 files, 8 tasks` (content head and after reconciliation) |
| `python3 scripts/test_validate_bootstrap.py` | `Ran 35 tests … OK`. Every negative case is detected, and the baseline and a well-formed unread command pass. See RET-0001 for the case list. |
| JSON parse `EXECUTION_STATE.json` | OK |
| Personal path / identity sweep over the tree | No matches |

No application tests exist, and none are claimed.

## CI

- `bootstrap-validation` (read-only, no secrets) now runs the validator **and** the negative suite. Its result on the final head is reported in PR #1 and the engineer's final report.
- `claude-bridge` is inert on this PR (enable variable unset). No run is expected.

## Automated Claude bridge — AUTO_AGENT_BRIDGE_BLOCKED

- **Provider:** GitHub (App, secret, variable, merge) and Anthropic (OAuth token).
- **Step reached:** official workflow authored, validated, and pushed to the PR branch in a disabled state.
- **Founder must authorize:**
  1. install or confirm the Claude GitHub App on `Jay-prodesign/sesli-ogren` (not verifiable from this environment);
  2. create the repository secret `CLAUDE_CODE_OAUTH_TOKEN` using `claude setup-token` (interactive; Claude Pro/Max). `ANTHROPIC_API_KEY` was not used because it is a paid-provider commitment;
  3. set the repository variable `CLAUDE_BRIDGE_ENABLED=true` (kill switch);
  4. merge to `main` (protected), because comment-triggered workflows run only from the default branch;
  5. recommended before step 3: branch protection on `main`;
  6. Brain write path: the ChatGPT GitHub connector's comment write currently returns 403. Grant it, or keep Drive → Engineer transcription.
- **Already safe:** workflow-level `permissions: {}`; job-level least privilege; trusted-role guard (`OWNER/MEMBER/COLLABORATOR`) plus the action's own write-access check; no `allowed_non_write_users` or wildcard bots; merge/ready/release/force-push tools disallowed; wake-up-only system prompt. The CMD/RET mailbox works without the bridge.
- **Verification plan once activated:** Founder or Brain comments `@claude` on a docs-only issue. The expected result is a Claude run that reads the control plane and replies without mutating `main`. Then record `VERIFIED_WORKING` in a new RET.

## Secrets / provenance

- No secrets, credentials, tokens, OAuth material, `.env` files, personal data, local paths, or Drive exports. The validator scans and the manual sweep are clean, and the final diff was reviewed.
- Provenance: all files were authored for this repository. The register has no entries. CI actions are referenced by tag, not vendored (`docs/provenance/README.md`). No donor code, no Flutter/application tree, no LICENSE.

## Deviations

See [RET-0001 § Deviations](returns/RET-0001.md#deviations). In summary:
(1) CMD-0001 is an engineer transcription;
(2) the Drive handoff's initial LA map numbering differs from the preserved repository allocation;
(3) corrections were folded into the original task scopes, and LA-0007 now also depends on LA-0008;
(4) `EXECUTION_STATE.json` is schema v2 with the handoff's minimum keys;
(5) the head SHA self-reference is handled as before;
(6) bridge write scopes need `main` branch protection before activation;
(7) the executability "mention" check is heuristic.
Also noted: the Drive lifecycle-stage numbering (bootstrap = "M3") differs from the master-sequence milestone numbering used in `TASKS.md` (bootstrap = M0). The mapping is documented in `TASKS.md`.

## Rollback

`main` is untouched. To undo only this correction round, revert the five commits
after `97e9040` on `chore/repository-bootstrap`, or reset the branch to `97e9040`
with Product Owner approval. To roll back the whole bootstrap, close PR #1
unmerged and delete the branch (Product Owner / Brain decision). No external state
was changed: no App was installed, no secret or variable was created, and branch
protection was not touched.

## Exact next action

**Brain:** re-review draft PR #1 against CLAUDE_HANDOFF_000 and the M3
acceptance checklist. Issue BOOTSTRAP_PASS, CHANGES_REQUIRED, or BLOCKED,
preferably as `docs/agent/commands/CMD-0002.md` (or via Drive for transcription).
**Founder (optional, parallel):** complete the bridge gates above. The engineer
takes no further action and does not start CLAUDE_HANDOFF_001.
