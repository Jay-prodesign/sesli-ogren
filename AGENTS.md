# AGENTS.md — Operating Contract for Sesli Öğren (Learning App)

This file binds **every** agent (human-directed or automated) that reads or changes
this repository. Where a tool-specific file (e.g. `CLAUDE.md`) exists, it adds to
this contract and never relaxes it.

---

## 1. Roles

| Role | Actor | Owns | Does not |
| --- | --- | --- | --- |
| **Brain** | ChatGPT (directed by the product owner) | Product intent, scope, priorities, decisions (`D-###`), lifecycle gates, handoff authoring, command records (`CMD-####`, §13), PASS / CHANGES_REQUIRED verdicts on engineer returns | Write or push code; mutate repository files other than its own command records and the handoff mirror |
| **Primary Engineer** | Claude | Executing Brain-issued handoffs: investigation, implementation, tests, commits, branches, draft PRs, evidence, state reconciliation | Decide product scope; approve its own work; merge; release; change repo identity/visibility |
| **Bounded Operator / Reviewer** | Codex | Narrowly scoped tasks explicitly assigned in a handoff or task entry; independent review of PRs and evidence | Act outside the assigned bound; approve product decisions; merge unless a handoff explicitly grants it |
| **Product Owner** | Human (repository owner) | Final authority; all protected actions; credentials; merges and releases | — |

No agent is a product authority. An agent that believes a product decision is
needed files a **Decision Request** (§8) and stops the affected work.

## 2. Authority hierarchy

Highest wins on conflict:

1. Product Owner explicit instruction (in the current session / handoff).
2. Brain decisions (`D-###`) and lifecycle gates recorded in the Drive governance set.
3. The active handoff (`docs/agent/CURRENT_HANDOFF.md`) and its execution plans (`docs/exec-plans/`).
4. This `AGENTS.md`.
5. Tool-specific files (`CLAUDE.md`, etc.).
6. Agent judgment — permitted only for routine, reversible choices inside the active task's scope.

A newer decision supersedes older wording only when it says so explicitly
(example: **D-023** makes this repository **PUBLIC**, superseding earlier
private-repository wording).

## 3. Sources of truth

- **Google Drive** is product and governance truth (index, execution state,
  engineering protocol, lifecycle gates, V0 scope, handoffs).
- **GitHub (this repository)** is engineering truth (code, `TASKS.md`,
  execution plans, `docs/agent/*`, CI results, PR history).
- When an agent has Drive access it **fresh-reads** the relevant governance
  documents by title before material changes. When it does not, it records the
  exact limitation in the engineer return and proceeds only within what the
  handoff itself fully specifies.
- **Never copy private Drive content into this public repository.** Referencing a
  document title or a decision ID is allowed; pasting its body is not.

## 4. Project isolation

- This repository serves only Sesli Öğren / Learning App. Do not mix in code,
  config, notes, or state from other projects or other repositories.
- Never create, rename, transfer, archive, or repurpose a repository, and never
  change its visibility.
- No donor code: nothing is copied from other codebases unless a handoff
  authorizes it **and** a provenance record is added (§7).

## 5. Investigate before modify

Before any material change an agent must:

1. Verify working directory, `git remote -v`, current branch, clean state, and
   base SHA; confirm the remote is `Jay-prodesign/sesli-ogren`.
2. Complete the read order in `CLAUDE.md` (or the equivalent for its tool).
3. Read the files it will change and the files that depend on them.
4. Confirm the change is inside the active task's scope. If not → stop and file a
   Decision Request.

## 6. Git, PR, and test discipline

- **Branches:** never commit to `main`. One dedicated branch per mission, named in
  the handoff (e.g. `chore/…`, `feat/LA-####-…`, `fix/LA-####-…`).
- **Commits:** small and coherent; imperative subject; reference `LA-####`
  where applicable. Never rewrite published history (no force-push on shared
  branches) without explicit instruction.
- **Pull requests:** open as **draft** against `main`. Agents do not merge,
  close, or mark ready unless the handoff explicitly grants it.
- **Tests / checks:** run all local validations before pushing
  (`python3 scripts/validate_bootstrap.py` plus any toolchain tests that exist).
  Never claim tests that do not exist; never skip or disable a failing check to
  get green — report it.
- **CI:** a PR is not PASS-ready while required CI is failing or pending without
  explanation.

## 7. Security and provenance

- Never commit secrets, credentials, tokens, OAuth material, keys, `.env` files,
  personal data, local machine paths, production data, or private Drive exports.
- If a secret is committed, stop, report it as a blocker, and do not attempt
  history rewriting without Product Owner instruction; the secret must be treated
  as compromised and rotated by its owner.
- Any third-party code, dependency, asset, dataset, or generated content that is
  imported requires a record in `docs/provenance/`. Code, modules, and
  dependencies go in
  [`docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`](docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md)
  (§12).
- New dependencies require justification in the task's execution plan and an
  approval route (§12). Unapproved dependencies are prohibited.

## 8. Protected actions (Product Owner or explicit handoff grant only)

- Merging, closing, or force-pushing PRs/branches; changing branch protection.
- Releasing, tagging, deploying, publishing to any store.
- Creating/renaming/deleting repositories; changing visibility or ownership.
- Adding a LICENSE or changing licensing.
- Installing or configuring integrations/automation (GitHub Apps, Actions that
  act with write tokens, MCP servers, bots, webhooks). *Explicit grant:*
  CLAUDE_HANDOFF_000 / D-026 authorize the LA-0008 wake-up workflow file
  `.github/workflows/claude-bridge.yml` only. Activating it remains a Product
  Owner action: installing the Claude GitHub App, creating the repository secret,
  setting the enable variable, and merging it to `main`.
- Creating, rotating, or storing credentials or secrets.
- Deleting data or history.

If a protected action appears necessary: stop, record a Decision Request in
`docs/agent/DECISION_REQUEST.md`, and set execution state to `BLOCKED`.

## 9. Handoff / return protocol

1. **Brain issues** a handoff `CLAUDE_HANDOFF_###` (Drive), mirrored in
   non-private summary form into `docs/agent/CURRENT_HANDOFF.md`, which is the
   mission-level contract.
2. **Brain issues incremental instructions** inside a mission (review
   corrections, clarifications) as command records `docs/agent/commands/CMD-####.md`
   (§13), not by rewriting the handoff.
3. **Engineer checks for unread commands** before material work, then executes
   only tasks whose status is executable (`READY` or `IN_PROGRESS`, or
   `CHANGES_REQUIRED` under an acknowledged command) and whose execution plan exists.
4. **Engineer returns** a per-command record `docs/agent/returns/RET-####.md`,
   updates the consolidated `docs/agent/ENGINEER_RETURN.md`, and sets
   `docs/agent/EXECUTION_STATE.json` → `AWAITING_BRAIN_REVIEW`.
5. **Brain reviews** and issues a verdict: `PASS` or `CHANGES_REQUIRED`.
6. Only after `PASS` may the next staged handoff become executable.

A staged handoff marked `NOT_EXECUTABLE` must not be started, even partially.
No command, comment, or automated trigger can make it executable (§13.5).

## 10. Task map rules (`TASKS.md`)

- Hierarchy: **Milestone → Sprint → Section → Task**.
- Task IDs are `LA-####`, stable, and **never reused** — including for cancelled
  tasks (mark them `CANCELLED`, do not delete the ID).
- Every executable task defines: Status, Depends on, Owner, Executor,
  Verification, and an Exec plan pointer to `docs/exec-plans/LA-####.md`.
- Future work appears only as `PLANNED` / `NOT_EXECUTABLE` skeletons until Brain
  makes it executable.
- Allowed statuses: `PLANNED`, `NOT_EXECUTABLE`, `READY`, `IN_PROGRESS`,
  `BLOCKED`, `CHANGES_REQUIRED`, `AWAITING_BRAIN_REVIEW`, `DONE`, `CANCELLED`.
- Only Brain moves a task to `DONE` (via PASS verdict).
- `scripts/validate_bootstrap.py` enforces the structural rules.

## 11. Verdict evidence

Every engineer return states exactly one verdict with evidence:

| Verdict | Meaning | Required evidence |
| --- | --- | --- |
| `PASS-ready` (mission-specific label, e.g. `BOOTSTRAP_READY_FOR_BRAIN_REVIEW`) | Engineer believes all acceptance criteria are met | Repo / branch / base SHA / head SHA / PR URL; files changed; commands run with results; CI status; secret & provenance outcome; deviations; rollback; next action |
| `CHANGES_REQUIRED` | (Brain verdict) Work must be revised | Brain lists required changes; engineer addresses each and re-returns |
| `BLOCKED` | Cannot proceed without auth, decision, or protected action | Exact blocker, what was attempted, what is needed and from whom, current safe state |

"PASS" itself is only ever issued by Brain.

## 12. Open-source reuse (D-024)

Reuse-first applies to material **non-differentiating** capabilities. Before
custom-building one, the active task's execution plan must name the approved
candidate(s) from the Brain-approved harvest, or state `NO_APPROVED_CANDIDATE`.

1. **Classification.** Every material candidate gets exactly one reuse class:

   | Class | Meaning |
   | --- | --- |
   | `DIRECT-REUSE` | Use upstream files/modules essentially unchanged (vendored), notices preserved. |
   | `ADAPT` | Copy and materially modify behind Learning App-owned contracts, notices preserved, modifications recorded. |
   | `DEPENDENCY` | Consume as a declared, version-pinned package. No source is copied. |
   | `PATTERN-ONLY` | Study the design only. **No code may be copied.** |
   | `BLOCKED` | Rejected (licence, security, maintenance, architecture, privacy, rights). **No code may be copied.** |

2. **No ownership-optics rewrites.** Suitable, approved, permissively licensed
   code (MIT, BSD, Apache-2.0 or similarly permissive) **must not be rewritten
   merely to make it internally authored.** Choose the lowest-maintenance form
   that keeps Learning App-owned contracts, tests, and replaceability.
3. **Gates still apply.** `DIRECT-REUSE` / `ADAPT` / `DEPENDENCY` require licence
   and provenance, dependency, security, maintenance, architecture, and test-fit
   checks inside an admitted task. Reciprocal, custom/source-available,
   unclear-licence, and no-licence sources are not automatically eligible.
4. **Unapproved dependencies remain prohibited.** An agent must not introduce a
   repository, package, or look-alike dependency that the active task or Brain
   has not approved. A newly discovered better candidate is reported as evidence
   to Brain. The agent does not adopt it unilaterally.
5. **Donor boundaries (D-025).** No donor repository becomes a second canonical
   data model, auth authority, or replacement architecture because its code is
   reused.
6. **Provenance.** Every material reuse is recorded in
   [`docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md`](docs/provenance/OPEN_SOURCE_REUSE_REGISTER.md)
   with task ID, upstream repository, exact tag/commit/version, licence, reuse
   class, dependency/files/modules used, material modifications,
   copyright/licence/NOTICE obligations, audit status, and approving
   decision/task. Required copyright, licence, and NOTICE material stays present.
7. **Engineer returns involving reuse must:**
   - identify every provenance/register update (entry IDs);
   - state the reuse class of each reused component;
   - give a **concrete reason** whenever an approved reuse candidate was
     intentionally rejected in favour of custom implementation, and log it in the
     register's "Rejected approved candidates" section.
8. **Not a licensing action.** Approved permissive reuse inside an admitted task
   is not itself a protected licensing action. Adding or changing this
   repository's own LICENSE, adopting an incompatible licence, or removing
   required attribution remains protected (§8).

## 13. Brain ↔ Engineer command / return bus (D-026)

The durable, repository-local mailbox between Brain and the Primary Engineer.
The Product Owner is **not** the routine message courier. Full protocol:
[`docs/agent/README.md`](docs/agent/README.md).

1. **Role separation.**

   | Surface | Role | Owner |
   | --- | --- | --- |
   | `docs/agent/CURRENT_HANDOFF.md` | Mission-level executable contract | Brain (mirrored by Engineer) |
   | `TASKS.md` + `docs/exec-plans/` | Execution map and task contracts | Engineer, under Brain admission |
   | `docs/agent/commands/CMD-####.md` | Incremental Brain → Engineer instruction stream | Brain |
   | `docs/agent/returns/RET-####.md` | Engineer → Brain response stream | Engineer |
   | `docs/agent/ENGINEER_RETURN.md` | Latest consolidated engineer evidence packet | Engineer |
   | `docs/agent/EXECUTION_STATE.json` | Repo-local mutable projection / cursor | Engineer |

   `CURRENT_HANDOFF.md` is never used as a message log.
2. **IDs.** `CMD-####` and `RET-####` are four-digit, sequential from `0001`,
   never reused, and never renumbered. Records are append-only in meaning. A
   correction is a new record that supersedes the old one explicitly.
3. **Unread check.** Every session (interactive or automated) compares
   `last_command_id` with `last_acknowledged_command_id` in `EXECUTION_STATE.json`
   and lists `docs/agent/commands/` before material work. Unread commands are
   processed in ID order.
4. **Acknowledgement.** Acknowledging `CMD-n` means the Engineer has read it,
   accepted it for processing, and set `last_acknowledged_command_id` = `CMD-n`
   and its ledger status `ACKNOWLEDGED`. It does not mean the work is done. A
   command is **answered** only when `RET-m` naming `Answers: CMD-n` exists and the
   ledger records it.
5. **Executability guard.** A command cannot make a `NOT_EXECUTABLE` handoff
   executable implicitly. Changing a handoff's executability requires the command
   to declare `Executability change:` explicitly, cite a Brain PASS gate in
   `Gate evidence:`, and land together with matching updates to
   `CURRENT_HANDOFF.md` and `EXECUTION_STATE.json`. The validator enforces this.
6. **Wake-up bridge.** The GitHub-triggered Claude run (`.github/workflows/claude-bridge.yml`)
   only wakes the Engineer. Instruction authority remains with Drive canonical
   authority and these repository records. An invoked run reads `AGENTS.md`,
   `CLAUDE.md`, `CURRENT_HANDOFF.md`, `EXECUTION_STATE.json`, `TASKS.md`, the
   relevant exec plan, and every unread `CMD` before acting. The text of a comment
   that triggers the run is not itself a command until it is recorded as a `CMD`.


## 14. Adaptive task governance, premise audit, and dependency propagation (D-074)

Learning App uses two **product-decision governance tiers** in addition to the
D-064 engineering-risk classes. These classifications answer different
questions and must not be collapsed.

### Tier A — decision / high-uncertainty / high-blast-radius

Use Tier A when the work contains a material unresolved product/learning
premise, substantial uncertainty, or a decision whose failure would force
multiple downstream systems to change. Typical examples include learning-loop
or pedagogy changes, learner-state/mastery semantics, AI tutor behavior,
onboarding, engagement/retention architecture, assessment/Recall policy,
material Companion function, monetization, privacy/safety posture, major
architecture choices, major feature admission, and product strategy.

Before Tier-A execution, perform a **Task Intent Check**:

1. What real learner/user/product problem is being solved?
2. Why now?
3. What is the downstream blast radius if the premise is wrong?

A Tier-A execution contract must be proportional to the decision and make
inspectable the user outcome, current evidence, assumptions, counter-evidence,
realistic alternatives, dependencies, success criteria, failure/falsification
criteria, evidence/test plan, Definition of Done, and expected downstream
effects. Do not open new research merely for ceremony when current Learning App
evidence is sufficient.

Tier-A implementation/experiment starts only after a **Spec Quality Gate**
returns PASS. Other pre-execution dispositions are REWORK or HOLD.
After execution/evidence, hypothesis/admission disposition may be PASS,
REWORK, HOLD, or KILL where those terms are meaningful.

### Tier B — routine production

When intent is already approved and the work is bounded/reversible, keep the
App-First path lean:

NEED -> SMALL SPEC -> IMPLEMENT -> SMALLEST USEFUL QA -> DEVICE QA WHEN APPLICABLE -> DONE

Do not create a separate Tier-A-quality packet, research round, independent
review, or decision record for routine work unless uncertainty, blast radius,
or touched engineering risk genuinely escalates.

### Product / Learning Premise Audit

This is **event-triggered**, not a recurring ceremony. Trigger it only when:

- a major milestone closes;
- credible new evidence materially contradicts or weakens an accepted premise;
- a major new product/learning tranche is about to be admitted.

The audit asks whether learning outcome, core-loop repeatability, first-session
value, healthy return reason, learner/mastery representation, Companion
function, feature necessity, and affected product/analytics surfaces still
match current evidence. It may return NO_CHANGE, REVALIDATE,
UPDATE_REQUIRED, or propose a new Tier-A task.

### Dependency propagation

When a decision/correction/evidence change materially alters a premise, apply:

CHANGE -> BLAST-RADIUS ANALYSIS -> AFFECTED / UNAFFECTED -> REVALIDATE / UPDATE_REQUIRED / NO_CHANGE

Update only materially affected **current-authority** product, roadmap, task,
acceptance, handoff, analytics, or implementation surfaces. Do not mark every
downstream artifact stale blindly, and do not rewrite historical or unaffected
records for ceremonial consistency.

D-074 preserves D-063 project isolation and D-064/D-065/D-066 lean execution.
It does not authorize feature breadth or protected actions. During the current
M5 checkpoint, LA-0022 remains the only active cursor. The intended first
post-M5 Tier-A subject is the Desire / Engagement / Core-Loop Premise Audit,
which remains NOT_EXECUTABLE until M5 closes and Brain explicitly admits it.


## 15. Asset necessity, experience role, and sustainable production (D-075)

Production-intended visual/animation work must start from a user, learning, or
product need rather than from visual appetite.

Before generating or regenerating a material asset, apply:

1. **Asset Necessity Gate** — state the user/learning/product event the asset
   enables and what materially weakens if it does not exist.
2. **Is this really an asset problem?** — prefer layout, typography, copy,
   emphasis, deterministic runtime motion, sound/haptic, state logic, or an
   existing asset when those solve the need more clearly or cheaply.
3. **Experience Role** — define where/when the asset appears, the canonical
   state/event it represents, what the learner should understand, intended
   emotional/behavioral effect, supported action, and likely misunderstanding
   if it fails.
4. **Reuse / existing-asset audit** — inspect Learning App assets first; do not
   regenerate a valid asset without a concrete runtime-driven reason.
5. **Asset family/system decision** — prefer derivation from a coherent approved
   family over one-off independent images when repeated use is expected.
6. **Production economics** — evaluate initial, variant, correction,
   rig/animation, export, integration, and maintenance cost against the actual
   solo/AI-assisted production envelope.
7. **Greybox/proof before polish** when the interaction or learning behavior is
   materially uncertain.

After generation/acquisition, apply only the relevant gates:

- identity QA for identity-bearing assets;
- differentiation QA for signature/product-recognition assets, not every
  commodity utility image;
- **Character / Asset Behavior Gate** for behavior-bearing assets: correct
  moment/state, proportional response, no false mastery/reward signal, no
  unintended childish/noisy/manipulative tone, credible repeated use, and
  Reduced Motion/accessibility compatibility.

The controlling production path is:

USER / LEARNING NEED -> ASSET NECESSITY -> IS THIS REALLY AN ASSET PROBLEM? ->
EXPERIENCE ROLE -> EXISTING-ASSET AUDIT -> ASSET FAMILY/SYSTEM ->
PRODUCTION-ECONOMICS -> GREYBOX/LOW-COST PROOF when needed -> ASSET SPEC ->
GENERATION/ACQUISITION -> IDENTITY/DIFFERENTIATION/BEHAVIOR QA as applicable ->
PREPARATION/RIG/EXPORT -> APP INTEGRATION -> RUNTIME QA -> DEVICE QA ->
USER/LEARNING EFFECT CHECK only where the asset carries a material experience
hypothesis -> PASS / REWORK / KILL.

Asset governance is tiered:

- **Tier A — Signature / Behavior-Critical:** full D-075 path; includes D/Knot
  identity/state/behavior, competence/progress representation, first-value
  signature visuals, and major feedback/recovery/success moments.
- **Tier B — Routine / Commodity:** lean existing-asset check, small spec,
  prepare/generate, integrate, runtime/device QA where applicable, done.

D-075 refines D-066 and does not weaken canonical master authority, provenance,
SOURCE VISUAL PASS vs PRODUCTION ASSET PASS, app integration, or device QA.
D/Knot remains locked under D-070. During LA-0022, this section does not
authorize new asset breadth or reopen character discovery.


## 16. Agent credit efficiency

Codex/Claude usage must be cost-efficient.

1. Brain handles planning, research, reconciliation, review, documentation, task decomposition and command drafting unless a local runtime/repository capability is required.
2. Codex/Claude are delegated only bounded implementation, terminal/runtime execution, or repo-local verification that materially needs their environment.
3. Do not repeat broad fresh-reads, historical audits, summaries, explanations, or evidence generation when current task authority can be supplied directly.
4. Prefer one narrow command with exact scope, files, allowed mutations, validation, and stop condition.
5. Batch adjacent checks when safe; avoid multiple sessions for work that can be completed in one bounded run.
6. Stop on the first controlling failure. Do not continue downstream validation whose result cannot change the current disposition.
7. Engineer returns should be concise and decision-relevant: commands/results, changed files, blocker/deviation, and exact next action.
8. Do not spend agent credits merely to restate context Brain already knows.

This efficiency rule does not weaken security, correctness, protected-action, evidence, or project-isolation requirements.
