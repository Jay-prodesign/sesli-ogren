# Open-Source Reuse Register (D-024)

Every material third-party reuse in this repository is recorded here: code,
modules, vendored files, and dependencies admitted as product-relevant. Rules:
[`AGENTS.md` §12](../../AGENTS.md#12-open-source-reuse-d-024).

- **Authority:** Decision D-024 (Open-Source Reuse-First Engineering Policy),
  refined for donors by D-025. This register is a repository projection. It
  does not approve anything: each entry cites the task or decision that
  admitted it.
- **Public repository:** entries contain only public upstream facts. Never paste
  private Drive content, credentials, or internal audit notes here.
- **Append-only in meaning:** do not delete an entry. When a reuse is removed,
  replaced, or re-audited, set `Audit status` to `WITHDRAWN` / `SUPERSEDED` and
  add a new entry if needed.

## Reuse classes

Every entry uses exactly one class:

| Class | Meaning | Product code may contain upstream code? |
| --- | --- | --- |
| `DIRECT-REUSE` | Upstream files or modules used essentially unchanged (vendored). | Yes, with notices preserved |
| `ADAPT` | Upstream code copied, then materially modified behind Learning App-owned contracts. | Yes, with notices preserved and modifications listed |
| `DEPENDENCY` | Consumed as a declared package or library at a pinned version. No source is copied. | No copy; lockfile/manifest pin |
| `PATTERN-ONLY` | Design or approach studied; no code copied. Used for unclear, reciprocal, or unsuitable licences, or for pure reference. | **No** |
| `BLOCKED` | Rejected for licence, security, maintenance, architecture, or rights reasons. | **No** |

## Audit status values

`CANDIDATE` · `AUDIT_IN_PROGRESS` · `APPROVED` · `REJECTED` · `WITHDRAWN` · `SUPERSEDED`

## Entry template

Copy this block for each entry. `REUSE-####` IDs are sequential and never reused.

```
### REUSE-#### — <component / capability>

| Field | Value |
| --- | --- |
| Task ID | LA-#### |
| Upstream repository | https://github.com/<owner>/<repo> |
| Exact tag / commit / version | <tag> @ <40-hex commit> (or package@version) |
| License | <SPDX identifier> (link to upstream LICENSE at that commit) |
| Reuse class | DIRECT-REUSE / ADAPT / DEPENDENCY / PATTERN-ONLY / BLOCKED |
| Dependency / files / modules used | <package name, or upstream paths -> repository paths> |
| Material modifications | <none / summary of changes> |
| Copyright / license / NOTICE obligations | <copyright lines kept, LICENSE/NOTICE file location, attribution surface> |
| Audit status | CANDIDATE / AUDIT_IN_PROGRESS / APPROVED / REJECTED / WITHDRAWN / SUPERSEDED |
| Approving decision / task | D-### and/or LA-#### (and Brain verdict reference) |
| Recorded | YYYY-MM-DD by <agent> |
```

## Rejected approved candidates

When a Brain-approved reuse candidate is intentionally **not** used in favour of
custom code, record it here with a concrete reason, as AGENTS.md §12 requires:

```
- <date> · LA-#### · <candidate + version> · rejected because <concrete reason:
  architecture / security / maintenance / privacy / licensing / test-fit / product risk>
```

None.

## Entries

None. The repository bootstrap (CLAUDE_HANDOFF_000, LA-0001 … LA-0008) imports no
donor code, third-party modules, or dependencies. All files were authored for this
repository. The CI workflows reference the public GitHub Actions `actions/checkout`
and `anthropics/claude-code-action` by major-version tag. These are CI tooling used
by reference, not product code copied into the repository. They are listed in
[`README.md`](README.md#ci-tooling-referenced-not-vendored) for transparency.
