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
| `Quality considerations (D-029)` | **Required for tasks under the active non-bootstrap milestone.** Cover only the concerns relevant to this task: security/privacy, AI boundaries, canonical data ownership, performance/accessibility, meaningful tests, observability, cost, dependencies/provenance, rollback/safe change, technical debt, evidence. Use N/A with a reason rather than an empty checklist. For major decisions, include the Final Engineering Test answers ([`AGENTS.md` §14](../../AGENTS.md#14-engineering-quality-d-029-and-experience-governance-d-028)). |

For tasks that implement a non-differentiating capability, `In scope` must also
name the approved reuse candidate(s) with their D-024 class, or state
`NO_APPROVED_CANDIDATE` ([`AGENTS.md` §12](../../AGENTS.md#12-open-source-reuse-d-024)).
