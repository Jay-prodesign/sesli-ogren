# AGENTS.md — Operating Contract for Sesli Öğren (Learning App)

This file binds **every** agent (human-directed or automated) that reads or changes
this repository. Where a tool-specific file (e.g. `CLAUDE.md`) exists, it adds to
this contract and never relaxes it.

---

## 1. Roles

| Role | Actor | Owns | Does not |
| --- | --- | --- | --- |
| **Brain** | ChatGPT (directed by the product owner) | Product intent, scope, priorities, decisions (`D-###`), lifecycle gates, handoff authoring, PASS / CHANGES_REQUIRED verdicts on engineer returns | Write or push code; mutate this repository directly |
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
- Any third-party code, asset, dataset, or generated content that is imported
  requires a record in `docs/provenance/` (source, license, date, scope, approver).
- New dependencies require justification in the task's execution plan.

## 8. Protected actions (Product Owner or explicit handoff grant only)

- Merging, closing, or force-pushing PRs/branches; changing branch protection.
- Releasing, tagging, deploying, publishing to any store.
- Creating/renaming/deleting repositories; changing visibility or ownership.
- Adding a LICENSE or changing licensing.
- Installing or configuring integrations/automation (GitHub Apps, Actions that
  act with write tokens, MCP servers, bots, webhooks).
- Creating, rotating, or storing credentials or secrets.
- Deleting data or history.

If a protected action appears necessary: stop, record a Decision Request in
`docs/agent/DECISION_REQUEST.md`, and set execution state to `BLOCKED`.

## 9. Handoff / return protocol

1. **Brain issues** a handoff `CLAUDE_HANDOFF_###` (Drive), mirrored in
   non-private summary form into `docs/agent/CURRENT_HANDOFF.md`.
2. **Engineer executes** only tasks whose status is executable (`READY` or
   `IN_PROGRESS`) and whose execution plan exists.
3. **Engineer returns** evidence in `docs/agent/ENGINEER_RETURN.md` and sets
   `docs/agent/EXECUTION_STATE.json` → `AWAITING_BRAIN_REVIEW`.
4. **Brain reviews** and issues a verdict: `PASS` or `CHANGES_REQUIRED`.
5. Only after `PASS` may the next staged handoff become executable.

A staged handoff marked `NOT_EXECUTABLE` must not be started, even partially.

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
| `PASS-ready` | Engineer believes all acceptance criteria are met | Repo / branch / base SHA / head SHA / PR URL; files changed; commands run with results; CI status; secret & provenance outcome; deviations; rollback; next action |
| `CHANGES_REQUIRED` | (Brain verdict) Work must be revised | Brain lists required changes; engineer addresses each and re-returns |
| `BLOCKED` | Cannot proceed without auth, decision, or protected action | Exact blocker, what was attempted, what is needed and from whom, current safe state |

"PASS" itself is only ever issued by Brain.
