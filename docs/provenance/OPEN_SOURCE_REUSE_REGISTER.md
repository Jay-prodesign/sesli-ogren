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

### REUSE-0001 — `set_updated_at()` trigger function

| Field | Value |
| --- | --- |
| Task ID | LA-0011 |
| Upstream repository | https://github.com/MoonlighC/ai-study-buddy |
| Exact tag / commit / version | main @ 317e21df9587a2ba6337e9802ae4119ad9b5e2e5 |
| License | MIT (LICENSE blob 3f057e54c9c63646842b73015685a6a3b4dcbb76; copy at `docs/provenance/licenses/MoonlighC-ai-study-buddy-MIT.txt`) |
| Reuse class | DIRECT-REUSE |
| Dependency / files / modules used | `supabase/migrations/001_initial_schema.sql` → `public.set_updated_at()` in `spike/architecture-proof/db/migrations/0001_canonical_core.sql` |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Header comment in the migration names the upstream, commit and MIT copyright; licence text kept in `docs/provenance/licenses/` |
| Audit status | APPROVED |
| Approving decision / task | D-024, D-025; CLAUDE_HANDOFF_001 / LA-0011 |
| Recorded | 2026-09-29 by Claude (Primary Engineer) |

### REUSE-0002 — Supabase tenancy, storage ownership and generation-attempt mechanics

| Field | Value |
| --- | --- |
| Task ID | LA-0011, LA-0013, LA-0014, LA-0015 |
| Upstream repository | https://github.com/MoonlighC/ai-study-buddy |
| Exact tag / commit / version | main @ 317e21df9587a2ba6337e9802ae4119ad9b5e2e5 |
| License | MIT (LICENSE blob 3f057e54c9c63646842b73015685a6a3b4dcbb76) |
| Reuse class | ADAPT |
| Dependency / files / modules used | Patterns and SQL shapes from `supabase/migrations/001_initial_schema.sql` (owner RLS policy form), `004_material_upload_storage.sql` (storage path ownership policies), `008_client_api_privileges.sql` (client privilege narrowing), `010_material_analysis_processing.sql` (attempt dispatch_state / budget_effect / lease-token / no-auto-resend semantics) → `spike/architecture-proof/db/migrations/0001_canonical_core.sql`, `0002_generation_rpcs.sql` |
| Material modifications | Re-keyed to canonical tables (accounts, materials, source_assets, extracted_contents, generation_jobs/attempts, artifacts); unified the donor's two generation authorities; clients reduced to SELECT-only with all writes via SECURITY DEFINER RPCs; single storage bucket policy set |
| Copyright / license / NOTICE obligations | Header comments in both migrations cite upstream + commit + MIT copyright; licence text in `docs/provenance/licenses/` |
| Audit status | APPROVED |
| Approving decision / task | D-024, D-025; CLAUDE_HANDOFF_001 / LA-0011, LA-0013–LA-0015 |
| Recorded | 2026-09-29 by Claude (Primary Engineer) |
