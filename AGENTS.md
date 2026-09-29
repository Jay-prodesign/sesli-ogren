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
7. **Checkpoint returns.** A long-running command, such as a whole mission, may
   receive interim `RET` records with `Disposition: PARTIAL`. The command stays
   `ACKNOWLEDGED` until a non-PARTIAL return answers it.

## 14. Engineering quality (D-029) and experience governance (D-028)

**D-029 — Engineering & Product Quality Constitution** (canonical Drive document
"ENGINEERING & PRODUCT QUALITY CONSTITUTION — Learning App") binds every
engineering agent. This section is the operational projection. The Drive document
is the full authority and is not copied here.

1. **Quality bar.** simple + secure + maintainable + observable + testable +
   performant + cost-conscious + evolvable. Build the smallest credible system
   that solves the current validated problem. New complexity, services,
   abstractions, or dependencies need a stated, concrete reason.
2. **Operational rules.**
   - Reuse proven platform or library capability before writing custom code (§12).
   - Keep code clear and boundaries narrow and real. Put provider, database, or
     vendor specifics behind adapters only where replacement matters.
   - Design security and privacy in from the start: deny by default, enforce
     server-side, isolate secrets, collect only minimum data, and keep sensitive
     data out of logs, analytics, and prompts.
   - Never treat AI output as trusted system truth by default. Each important
     fact has one canonical owner.
   - Measure before optimizing performance. Design accessibility from the start
     for user-facing work.
   - Test according to risk (authn/authz, user data, migrations, AI boundaries,
     critical workflows), not coverage percentages.
   - Make failures observable without leaking sensitive data, and degrade
     gracefully.
   - Treat cost (tokens, inference, storage, jobs) as an architectural constraint.
   - Record material technical debt with its reason, scope, risk, and
     remediation. It must never pass as final architecture.
   - Prefer small, reversible changes with an explicit rollback.
   - Back completion claims with repository, test, or runtime evidence, never
     with documentation alone.
3. **Final Engineering Test.** Before accepting a major implementation decision,
   answer these ten questions:
   1. Is it necessary now?
   2. Is it the simplest credible option?
   3. Is it secure by default?
   4. Can another engineer understand and modify it?
   5. Is it testable?
   6. Is it observable on failure?
   7. Is it replaceable or evolvable?
   8. Are the privacy implications acceptable?
   9. Is the operational cost reasonable?
   10. Does it solve today's problem without unnecessarily constraining tomorrow?

   If a material answer is unclear, the decision is unfinished. Mark an
   irrelevant dimension N/A with a short reason. Apply the test in proportion to
   risk: no checklist theatre and no compliance infrastructure.
4. **Where it appears.** Exec plans for tasks under the active, non-bootstrap
   milestone carry a `## Quality considerations (D-029)` section (template in
   [`docs/exec-plans/README.md`](docs/exec-plans/README.md)). Mission returns state
   where D-029 was applied, the Final Engineering Test disposition for major
   decisions, and any quality debt.
5. **D-028 — Creative & Product Experience governance.** Engineering may
   prototype user-facing ideas. It must not silently turn prototype UI,
   component-library defaults, or implementation convenience into canonical
   product design. Report unresolved user-facing choices to Brain as
   `OPEN DESIGN DECISION` / `EXPERIMENT`. Label proof-only UI as such, and never
   present it as production-complete UX.
