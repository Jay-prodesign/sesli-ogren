# LA-0010 — Upstream fresh audit and reuse-admission matrix

- Task: [LA-0010](../../exec-plans/LA-0010.md) · Mission: CLAUDE_HANDOFF_001 · Date: 2026-09-29
- Method: shallow `git clone` of each upstream default branch; LICENSE/NOTICE read at the exact
  commit; manifests inspected; donor test suites **executed** where the runtime is available.
  npm facts from `registry.npmjs.org`. No donor code has been copied into this repository by LA-0010.

## 1. Exact upstream identity

| Upstream (canonical) | Commit audited | Commit date | Brain pin | Drift | Licence (file at commit) | Runtime |
| --- | --- | --- | --- | --- | --- | --- |
| MoonlighC/ai-study-buddy | `317e21df9587a2ba6337e9802ae4119ad9b5e2e5` | 2026-08-21 | same | none | MIT, © 2026 MoonlighC | Flutter (Dart ^3.12) + Supabase Postgres + Deno Edge Functions |
| lfnovo/open-notebook | `3127f14ea9dbb519f0e4ddc64a0742ca644ba6ef` | 2026-09-12 | same | none | MIT, © 2024 Luis Novo | Python ≥3.11 FastAPI + SurrealDB + LangChain/Esperanto; Next.js UI |
| zijinz456/OpenTutor | `db15d901a7c5c5f46941487ca4ebc2cfb20425c2` | 2026-09-27 | same | none | MIT, © 2026 Zijin Zhang | Python API (Alembic/SQLAlchemy) + Next.js 16 / React 19 web |
| kirill-markin/flashcards-open-source-app (Nibomo) | `cafb497df760e0b4aae2f5ea4d553726f2fe0dac` | 2026-09-26 | same | none | MIT, © 2026 Kirill Markin; `THIRD_PARTY_NOTICES.md` (ts-fsrs 5.2.3 MIT, alea MIT, lottie Apache-2.0/MIT) | Native iOS (Swift) + Android (Kotlin) + TS backend + web/admin |
| LRriver/NotebookLM-Lite | `0fb41d0d79267b29300ba31c12b8a5217cf416ad` | 2026-07-10 | same | none | Apache-2.0 (no NOTICE file) | Python FastAPI; deps include litellm, docling, dashscope, langgraph |
| vercel/ai | `546a6f8876b0de68452d71a3e49716bcdf7f40c9` | 2026-09-28 | `1040e97…` | **moved** (monorepo HEAD advances daily; audited npm versions below instead) | Apache-2.0, © 2023 Vercel | TypeScript monorepo, 80 packages |

**vercel/ai npm packages (latest at audit):**

| Package | Version | Licence | engines | Runtime deps | Unpacked size |
| --- | --- | --- | --- | --- | --- |
| `ai` | 7.0.122 | Apache-2.0 | node ≥22 | `@ai-sdk/gateway` 4.0.100, `@ai-sdk/provider` 4.0.19, `@ai-sdk/provider-utils` 5.0.51; peer `zod` | 7.76 MB |
| `@ai-sdk/provider` | 4.0.19 | Apache-2.0 | node ≥22 | `json-schema` | 0.67 MB |
| `@ai-sdk/provider-utils` | 5.0.51 | Apache-2.0 | node ≥22 | `undici`, `@workflow/serde`, `eventsource-parser`, `@standard-schema/spec`; peer `zod` | 1.20 MB |
| `@ai-sdk/openai` | 4.0.81 | Apache-2.0 | node ≥22 | provider + provider-utils; peer `zod` | 3.32 MB |

Finding: the umbrella `ai` package hard-depends on `@ai-sdk/gateway`. Using `ai` pulls the Vercel AI
Gateway client into the bundle even when it is not called. The Deno runtime smoke and final
decision are in LA-0012.

Secondary references, not audited in depth (no Python service boundary is justified for the spike):
lfnovo/esperanto (Python, MIT) and docling-project/docling (Python, MIT) → **PATTERN-ONLY / deferred**.
open-spaced-repetition/dart-fsrs → **V1_OR_LATER_DEFERRED** (V0 contracts do not admit an SRS engine).

## 2. Donor test posture (executed)

Commands and full output are reproducible with the harness in
[`spike/architecture-proof/db/`](../../../spike/architecture-proof/db/). The harness runs a local Postgres 16
with a minimal Supabase shim, because the Supabase CLI and Docker are unavailable in this environment.

| Donor suite | Command | Result |
| --- | --- | --- |
| MoonlighC SQL migrations (35 files, 10,297 lines) | `run_sql_suite.sh donor_baseline <migrations> <tests>` | **35/35 applied** as the non-superuser `postgres` role |
| MoonlighC SQL tests at HEAD (26 psql scripts) | same | **10/26 pass** at HEAD |
| MoonlighC SQL tests per migration step | `find_test_migration_step.sh` (template DB after every migration) | **24/26 pass at the migration step they were written for**. 2 never pass (`account_deletion_processing_cascade`, `material_analysis_reproduction_diagnostic_cleanup`). `phase_c_role_portability` passes at steps 33–34 but **fails at HEAD (35)** |
| MoonlighC Deno edge-function tests | `deno test -A --no-check --config <fn>/deno.json` per function (Deno 2.9.7) | **404/404 pass** (13 suites) |
| MoonlighC Flutter | `flutter pub get && flutter analyze && flutter test` (Flutter 3.47.5 / Dart 3.13.4) | analyze: **1 warning** (`unawaited_return_in_try_block`, `lib/features/auth/supabase_auth_repository.dart:222`); tests: **633/633 pass** |
| Open Notebook, OpenTutor, Nibomo, NotebookLM-Lite | not executed | Runtime mismatch (Python / native mobile / Next.js). Classified PATTERN-ONLY below, so their suites are not load-bearing for the spike |

Interpretation: MoonlighC's Dart and Deno suites are genuine regression suites and are green at HEAD.
Its SQL tests are migration-step verification scripts and are **not** maintained against HEAD. An
adapted schema therefore needs its own HEAD-level SQL regression suite. That cost is counted in LA-0016.

## 3. Capability scope and reuse classification

Scope classes: **RS** = REQUIRED_FOR_SPIKE, **V0L** = V0_CANDIDATE_LATER, **V1** = V1_OR_LATER_DEFERRED.

| Capability | Scope | Candidate | Reuse class | Rationale |
| --- | --- | --- | --- | --- |
| Auth / account | RS | MoonlighC (Supabase Auth, Flutter auth repository) | **ADAPT** | Same stack; 633 green Flutter tests include auth flows. Nibomo PATTERN-ONLY for recovery hardening |
| Tenancy / RLS | RS | MoonlighC migrations (RLS + FORCE RLS, owner checks in definers) | **ADAPT** (after canonical mapping) | Strongest donor asset; SQL must be re-keyed to canonical tables (LA-0011) |
| Material upload / storage | RS | MoonlighC storage policies (`{user_id}/…` paths, private buckets) | **ADAPT** | Same platform |
| Parsing / OCR / chunking | V0L | MoonlighC `extract-*-text` (unpdf); Docling | MoonlighC **ADAPT later**; Docling **PATTERN-ONLY** | The spike uses deterministic pasted text; parsing is not load-bearing for the proof |
| Retrieval / citations | V0L | Open Notebook, NotebookLM-Lite `RAGService` | **PATTERN-ONLY** | Python runtime; EvidenceRef contract is Learning App-owned |
| Summary generation | RS | MoonlighC `generation_runtime` / `material_analysis` + Learning App seam | **ADAPT** orchestration, **CUSTOM** seam (LA-0012) | Donor provider code is OpenAI-specific (`openai_adapter.ts`) |
| Flashcards / quiz | V0L | MoonlighC | **ADAPT later** | Not needed for the Summary proof |
| Job / retry / idempotency | RS | MoonlighC `material_processing_jobs/attempts`, retry authorizations, fingerprints | **ADAPT** | Rich, tested mechanics; must collapse into canonical GenerationJob/Attempt (LA-0011/0015) |
| Provider routing | RS | `@ai-sdk/*` (DEPENDENCY hypothesis), direct fetch, Open Notebook | decided in LA-0012 | Deno smoke required |
| Audio / TTS | V0L | Open Notebook podcast, NotebookLM-Lite TTS interface | **PATTERN-ONLY** | Out of spike scope |
| Study sessions | V0L | MoonlighC migration 026 | **ADAPT later** | — |
| Spaced repetition | V1 | dart-fsrs, Nibomo ts-fsrs adaptation, OpenTutor | **DEFERRED** | V0 does not admit SRS |
| Progress / mastery | V1 (mastery) / V0L (progress) | MoonlighC 027; OpenTutor BKT/KG | MoonlighC **ADAPT later**; OpenTutor **PATTERN-ONLY** | V1 firewall |
| Offline / sync | V0L | Nibomo | **PATTERN-ONLY** | Native stacks; no V0 offline requirement admitted |
| Usage / cost / quota | RS (seam) | MoonlighC `usage_*` / tester usage | **ADAPT** | The seam must be server-authoritative |
| Deletion / export | V0L | MoonlighC `delete-*` functions (88 green tests) | **ADAPT later** | Reuse after canonical mapping |
| Analytics | V0L | — | **CUSTOM** per the Learning App event contract | Donor code PATTERN-ONLY |
| CI / release | RS (CI) | Learning App CI; Nibomo release discipline | **CUSTOM** CI; Nibomo **PATTERN-ONLY** | — |

No `BLOCKED` classifications were required: all audited top-level licences are permissive. `fsrs-rs-dart`
remains `BLOCKED_PENDING_LICENSE_PROOF` per the Brain pre-audit and is unused.

## 4. Rights and obligations carried forward

- MIT (MoonlighC, Open Notebook, OpenTutor, Nibomo): retain the copyright and permission notice in any copied or
  adapted file set. Adapted files must record their upstream path and commit.
- Apache-2.0 (NotebookLM-Lite, vercel/ai): retain the licence and state modifications. No NOTICE file is present
  in NotebookLM-Lite at the audited commit.
- Asset, model and data rights: MoonlighC contains no bundled models or datasets. Its `assets/` folder is app
  artwork and is **not** reused by the spike.

## 5. D-029 notes

- Evidence over claims: every test count above comes from a command run in this task.
- Dependencies: none added by LA-0010.
- Debt surfaced: donor SQL tests are not HEAD regression tests; `phase_c_role_portability` fails at donor HEAD.
