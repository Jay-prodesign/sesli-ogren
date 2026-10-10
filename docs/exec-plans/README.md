## Founder execution-cadence correction — 2026-10-08

**Apply across Learning App, risk-proportionately:** Admit one cohesive user-visible deliverable as the work unit (not every minor UI element). Once task spec and main constraints are clear, carry out implementation continuously and autonomously to a meaningful milestone. Commit/push related edits together rather than making a new git commit/CI run for each cosmetic adjustment; use exact read/compile feedback during development where justified. A task's required QA gate is a **milestone/phase boundary**, not an instruction to run its entire test suite after every sub-edit. Material risk to security/privacy, canonical learning truth/source provenance, data integrity, runtime stability or a blocked build requires immediate focused verification.

For visually driven tasks, **stabilize one declared primary viewport and the COMPLETE connected flow first**, critically review authentic runtime at that reference and obtain protected Founder visual-direction approval when required; only then run the responsive/dynamic-type adaptation batch and its matrix QA. Preserve device QA and independent acceptance at release; this changes staging, not quality requirements. Do not mistake CI PASS for human visual preference, or hand off dozens of tiny reviews. LA-0040 currently uses **390×844 primary → Founder art lock → 320/360/390/430 with 1.3×/1.5× → D-068 device/release**, as detailed in its task spec and visual QA gate.

---

# Execution Plans

One file per active task: `LA-####.md`. A task in `TASKS.md` is only executable
when its plan exists here and its status is `READY` or `IN_PROGRESS` (or
`CHANGES_REQUIRED` under an acknowledged command). Future milestones get plans
only when Brain admits them.

Plans are execution projections of Drive authority (D-019). They never widen
product or architecture authority, and they never contain private Drive content,
secrets, or speculative product design.

## Required structure (validator-enforced)

Header fields: `**Status:**` (must match `TASKS.md`), `**Handoff:**`,
`**Executor:**`, `**Owner / verifier:**`. Then these `##` sections, in any
order:

| Section | Content |
| --- | --- |
| `Objective` | What the task achieves, in one or two sentences. |
| `Authoritative source references` | Drive document titles / decision IDs this plan projects. |
| `In scope` | What may be changed. |
| `Out of scope` | What must not be changed. |
| `Dependencies` | `LA-####` prerequisites, or `none`. |
| `Steps` | Ordered, concrete actions (optional but recommended). |
| `Acceptance criteria` | Checkable statements. |
| `Required tests / evidence` | Commands or observations that prove the criteria. |
| `Rollback / migration notes` | How to undo safely; migration impact or "none". |
| `Escalation conditions` | When to stop and file a Decision Request. |
| `Expected return` | What the engineer reports and where. |

For tasks that implement a non-differentiating capability, `In scope` must also
name the approved reuse candidate(s) with their D-024 class, or state
`NO_APPROVED_CANDIDATE` ([`AGENTS.md` §12](../../AGENTS.md#12-open-source-reuse-d-024)).

## Founder-mandated task specification and QA admission — 2026-10-08

**No material task is executable merely because it has a title.** Before starting each newly admitted or materially expanded task, make its implementation contract sufficient for an engineer to work without guessing and for an independent reviewer to give an evidence-grounded PASS/FAIL:

1. **Outcome/why:** concrete user/runtime need and what materially changes when solved.
2. **Scope and exclusions:** exact affected screens, code/data contracts, dependencies, source-of-truth and non-goals.
3. **Behaviors:** representative nominal path, invalid/missing/boundary input, interrupted/retry/restore paths and truth/security/privacy constraints proportionate to risk.
4. **Acceptance:** observable assertions and a clear DONE boundary, including what remains deliberately deferred.
5. **Quality gate:** specify relevant focused unit/widget/integration/device/human/perceptual checks, the expected result evidence, automatic FAIL/RETURN conditions and what an unverified result must be labeled.
6. **Release/rollback:** protect users and proven product truth; identify reversible versus protected operations.

**Tier A:** High-risk user/product/learning/visual commitments need decision-grade detail, explicit quality/spec gate before substantive implementation, risk-based QA and an independent/Founder disposition where required. **Tier B:** Reversible low-risk work gets a small but *real* spec and focused QA inside its existing execution plan; do not create a separate document or bureaucracy merely to satisfy a template.

Do not mark task DONE from source review, passing internal tests when real-device/UX proof is required, or an average score hiding a HIGH/BLOCKER. No automated/internal score substitutes for a protected Founder product decision. Record PASS / FAIL / BLOCKED / DEFERRED with the tested SHA or evidence where applicable. Reuse existing QA contracts rather than duplicating gates.

For currently active visual rework see LA-0040_FOUNDER_FAIL_REWORK_SPEC.md and the existing LA-0040_VISUAL_QUALITY_GATE.md; no new task ID is created by that corrective scope.
