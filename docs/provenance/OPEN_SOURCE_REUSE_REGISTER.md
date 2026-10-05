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

- 2026-09-29 · LA-0012 · vercel/ai `ai@7.0.118` / `@ai-sdk/*` (Apache-2.0; D-025 refinement 2 preferred DEPENDENCY) · rejected for now because the spike needs one structured-output call. The SDK adds ~94× the bundle (307.7 KB vs 3.3 KB minified), 11 transitive packages versus 0, always pulls in the unused `@ai-sdk/gateway` + `@vercel/oidc` clients, and churns at 35 releases in 30 days against Deno's 24 h minimum dependency age. It is Deno-compatible (evidence: `docs/architecture/spike/LA-0012-provider-seam.md`), so it remains a DEPENDENCY candidate behind the same contract when streaming, tools, or multi-provider routing are admitted.

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

### REUSE-0003 — `flutter_lints` (dev-only lint rules for the proof client)

| Field | Value |
| --- | --- |
| Task ID | LA-0013 |
| Upstream repository | https://github.com/flutter/packages (pub.dev package `flutter_lints`) |
| Exact tag / commit / version | flutter_lints 6.0.0 (+ transitive `lints` 6.1.0), locked in `spike/architecture-proof/client/pubspec.lock` |
| License | BSD-3-Clause (© 2013 The Flutter Authors) |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | `dev_dependencies` of `spike/architecture-proof/client` (analysis rules only; not shipped) |
| Material modifications | none |
| Copyright / license / NOTICE obligations | None for dev-only use; the package is not redistributed |
| Audit status | APPROVED |
| Approving decision / task | D-015 (Flutter client), D-024; LA-0013. Part of the Flutter SDK's standard project template, so no new vendor (D-031) |
| Recorded | 2026-09-29 by Claude (Primary Engineer) |

### REUSE-0004 — `subosito/flutter-action` (CI: Flutter SDK setup for the proof client)

| Field | Value |
| --- | --- |
| Task ID | LA-0017 (CMD-0008) |
| Upstream repository | https://github.com/subosito/flutter-action |
| Exact tag / commit / version | v2.23.0 @ 1a449444c387b1966244ae4d4f8c696479add0b2 (pinned by SHA in `.github/workflows/flutter-proof.yml`) |
| License | MIT (© 2019 Alif Rachmawadi), `LICENSE` at that commit |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | GitHub Action `uses:` reference only; no source copied. Installs the official Flutter SDK from `storage.googleapis.com/flutter_infra_release` at the `.flutter-version` pin |
| Material modifications | none. `cache: false` and `pub-cache: false`, so the action's internal mutable-tag `actions/cache@v5` steps do not execute |
| Copyright / license / NOTICE obligations | None; the action is referenced, not redistributed |
| Audit status | APPROVED |
| Approving decision / task | CMD-0008 (Brain-verified SHA); D-024; LA-0017. Read-only workflow, no secrets; runs on GitHub (approved stack) and fetches the official Flutter SDK (approved stack) |
| Recorded | 2026-09-30 by Claude (Primary Engineer) |

### REUSE-0005 — `actions/checkout` (CI: repository checkout, SHA-pinned in flutter-proof)

| Field | Value |
| --- | --- |
| Task ID | LA-0017 (CMD-0008) |
| Upstream repository | https://github.com/actions/checkout |
| Exact tag / commit / version | v4.4.0 @ 11d5960a326750d5838078e36cf38b85af677262 in `.github/workflows/flutter-proof.yml`. The existing `bootstrap-validation` and `spike-proof` workflows keep their `@v5` tag reference unchanged (CMD-0008: do not normalize unrelated workflows) |
| License | MIT (© 2018 GitHub, Inc. and contributors), `LICENSE` at that commit |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | GitHub Action `uses:` reference only; `persist-credentials: false` |
| Material modifications | none |
| Copyright / license / NOTICE obligations | None; the action is referenced, not redistributed |
| Audit status | APPROVED |
| Approving decision / task | CMD-0008 (Brain-verified SHA); D-024; LA-0017 |
| Recorded | 2026-09-30 by Claude (Primary Engineer) |

### REUSE-0006 — `flutter_lints` (dev-only lint rules for production-shaped M5 app)

| Field | Value |
| --- | --- |
| Task ID | LA-0018 |
| Upstream repository | https://github.com/flutter/packages |
| Exact tag / commit / version | flutter_lints 6.0.0 exact-pinned in `app/pubspec.yaml`; lockfile resolution PASS in M5 bounded validation run 37334117375 |
| License | BSD-3-Clause (© The Flutter Authors) |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | `dev_dependencies` of `app/`; analysis only |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Dev-only; not redistributed as application runtime code |
| Audit status | APPROVED |
| Approving decision / task | D-015, D-024; D-071 / LA-0018 |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |

### REUSE-0007 — `crypto` SHA-256 source identity

| Field | Value |
| --- | --- |
| Task ID | LA-0019 |
| Upstream repository | https://github.com/dart-lang/core |
| Exact tag / commit / version | crypto 3.0.7 exact-pinned in `app/pubspec.yaml`; lockfile resolution PASS in M5 bounded validation run 37334117375 |
| License | BSD-3-Clause (© Dart project authors) |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | SHA-256 only for deterministic content/source-version identity |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Preserve package licence/attribution through Flutter-generated bundled notices |
| Audit status | APPROVED |
| Approving decision / task | D-024; D-071 / LA-0019 |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |

### REUSE-0008 — `sqflite` local canonical M5 persistence

| Field | Value |
| --- | --- |
| Task ID | LA-0019 |
| Upstream repository | https://github.com/tekartik/sqflite |
| Exact tag / commit / version | sqflite 2.4.4 exact-pinned in `app/pubspec.yaml`; lockfile resolution PASS in M5 bounded validation run 37334117375 |
| License | BSD-2-Clause |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | Local SQLite persistence for learner-scoped Material/SourceVersion truth during the admitted M5 slice |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Preserve package licence/attribution through bundled notices; no server/production DB mutation |
| Audit status | APPROVED |
| Approving decision / task | D-024; accepted M4 persistence semantics; D-071 / LA-0019 |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |

### REUSE-0009 — `sqflite_common_ffi` deterministic SQLite tests

| Field | Value |
| --- | --- |
| Task ID | LA-0019 |
| Upstream repository | https://github.com/tekartik/sqflite |
| Exact tag / commit / version | sqflite_common_ffi 2.4.3 exact-pinned as a dev dependency; lockfile resolution PASS in M5 bounded validation run 37334117375 |
| License | BSD-2-Clause |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | Test-only in-memory SQLite factory for tenant/idempotency/supersession/deletion tests |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Test-only dependency; not part of the mobile runtime contract |
| Audit status | APPROVED |
| Approving decision / task | D-024; D-071 / LA-0019 |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |

### REUSE-0010 — `pdfrx` bounded PDF text extraction

| Field | Value |
| --- | --- |
| Task ID | LA-0019 |
| Upstream repository | https://github.com/espresso3389/pdfrx |
| Exact tag / commit / version | pdfrx 2.6.1 exact-pinned in `app/pubspec.yaml`; lockfile PASS resolves pdfrx_engine 0.6.1 + pdfium_flutter 0.3.1; real two-page native PDF engine probe PASS in run 37334117375 |
| License | MIT for pdfrx/pdfrx_engine/pdfium_flutter; bundled PDFium is BSD-style with its own third-party notices |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | Low-level `PdfDocument.openData` + per-page `loadText()` only; no PDF viewer/editing surface admitted |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Preserve MIT/BSD and PDFium third-party notices in distributable notice surface; lockfile is evidence for exact transitive resolution |
| Audit status | APPROVED |
| Approving decision / task | D-024; D-071 / LA-0019 bounded dependency audit |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |



### REUSE-0011 — `supabase_flutter` authenticated learner session

| Field | Value |
| --- | --- |
| Task ID | LA-0022 |
| Upstream repository | https://github.com/supabase/supabase-flutter |
| Exact tag / commit / version | supabase_flutter 2.17.2 exact-pinned in `app/pubspec.yaml`; lock/transitive resolution PASS in M5 bounded validation run 37334117375; live project auth evidence remains blocked only by missing client-safe project URL/publishable key |
| License | MIT |
| Reuse class | DEPENDENCY |
| Dependency / files / modules used | Flutter client bootstrap + persisted Auth session + anonymous authenticated user creation only |
| Material modifications | none |
| Copyright / license / NOTICE obligations | Preserve MIT/package attribution through Flutter notice surface |
| Security/config boundary | Project URL + publishable key supplied via Flutter `--dart-define`; no secret/service-role key in repository. Anonymous sign-in must be explicitly enabled in the selected Supabase project; public-release anti-abuse/captcha posture remains a later release gate. |
| Audit status | APPROVED FOR M5 IMPLEMENTATION / LIVE PROJECT CONFIG PENDING |
| Approving decision / task | D-024; canonical Supabase Auth direction; D-071 / LA-0022 |
| Recorded | 2026-10-04 by ChatGPT (Brain delegate) |
