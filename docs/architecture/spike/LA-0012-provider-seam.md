# LA-0012 — Provider-neutral generation capability seam

- Task: [LA-0012](../../exec-plans/LA-0012.md) · Mission: CLAUDE_HANDOFF_001 · Date: 2026-09-29
- Code: [`spike/architecture-proof/functions/`](../../../spike/architecture-proof/functions/) (Supabase Edge / Deno TypeScript)

## 1. Design

| Piece | File | Role |
| --- | --- | --- |
| Contract | `_shared/generation/contract.ts` | The Learning App-owned `StructuredGenerationCapability`: request (task, attempt key, authorized source text, output locale) → `ok` (typed `SummaryOutput`, usage, execution ref) or `failed` with class `retryable` / `final` / `ambiguous`. **It has no imports** (test-enforced). |
| Deterministic fake | `_shared/generation/fake_provider.ts` | Reproducible output and execution ref, with scriptable failures. It needs no credentials and no network. |
| HTTP adapter | `_shared/generation/fetch_adapter.ts` | A dependency-free, OpenAI-compatible `chat/completions` adapter using JSON-schema output. The provider shapes stay inside this file. It forwards the attempt key as `idempotency-key`. A transport error after send is classed as `ambiguous`, so it is never auto-resent. |
| Worker | `generation-worker/worker.ts` | Runs claim → **record dispatch** → provider → complete/fail through the `WorkerDb` port (service-role RPCs). |
| Harness DB port | `generation-worker/psql_worker_db.ts` | Test/harness only (psql). Production uses the Supabase service client. |

No provider or vendor was selected. The fetch adapter is a vendor-neutral shape. Choosing a vendor, supplying
credentials, and spending money are separate Founder gates (D-031), and the spike calls no live provider.

## 2. Evidence (commands run)

| Check | Command (from `spike/architecture-proof/functions`) | Result |
| --- | --- | --- |
| Adapter-contract + worker tests + DB integration | `LA_TEST_DB=la_e2e deno test -A .` (Deno 2.9.7) | **13/13 passed**, run twice |
| Type check | `deno check .` | clean |
| Lint / format | `deno lint .` / `deno fmt --check .` | clean |
| Own seam bundle | `deno bundle --minify` of the worker + fetch adapter | **3.3 KB** (1.6 KB gzip), **0** external packages, module graph 10.4 KB |

## 3. Vercel AI SDK evaluation (DEPENDENCY hypothesis, D-025 refinement 2)

Script: [`spike/architecture-proof/evaluation/ai_sdk_deno_smoke.ts`](../../../spike/architecture-proof/evaluation/ai_sdk_deno_smoke.ts).
It evaluates locally only (D-031); nothing is added to the product.

| Check | Result |
| --- | --- |
| Version | `ai@7.0.122` (latest) is **blocked by Deno's 24-hour minimum dependency age** supply-chain policy. The policy was not disabled. `ai@7.0.118` was used, the newest release older than 36 h. |
| Release cadence | **35** `ai@7.0.x` releases in the last 30 days. |
| Deno runtime | `generateObject` with `MockLanguageModelV4` returns the typed object: **works**. |
| `deno check` | passes once the mock uses the V4 usage/finish-reason shapes. |
| Dependency graph | **11 npm packages**, including `@ai-sdk/gateway`, `@vercel/oidc`, `undici`, `zod`. `ai` hard-depends on the Gateway client even when it is unused. All declare `node >= 22`. |
| Bundle | **307.7 KB minified (84.5 KB gzip)**; module graph 17.7 MB |
| Licence | Apache-2.0 (all four `@ai-sdk/*` + `ai`) |

### Decision: CUSTOM fetch adapter now; SDK stays `DEPENDENCY` candidate (not adopted)

The SDK is compatible, but it is not the lowest-maintenance form for today's need, which is one structured-output call:

- about 94× the bundle size of the seam, and 11 transitive packages versus 0;
- the unused Vercel Gateway and OIDC client are always pulled in, which conflicts with "no implicit Gateway";
- a very high release cadence (35 in 30 days) meets Deno's 24 h age policy, which adds upgrade friction;
- the contract already isolates the choice. Adopting the SDK later means adding one adapter file behind the
  same `StructuredGenerationCapability`, with no domain change.

**Revisit trigger:** multi-provider routing, streaming, tool calling, or multimodal inputs become admitted scope.
This is logged in the register's "Rejected approved candidates" section.

## 4. Final Engineering Test — SDK vs fetch adapter (D-029)

| # | Question | Answer |
| --- | --- | --- |
| 1 | Necessary now? | A provider seam is required by acceptance criteria 2 and 6. Only the minimal adapter is needed. |
| 2 | Simplest credible? | Yes: ~110 lines, platform `fetch`, no dependencies. |
| 3 | Secure by default? | Yes. The key is passed in server-side, never logged or returned (test-enforced), with a timeout and no retries inside the adapter. |
| 4 | Understandable? | Yes: one file per concern, with provider shapes local to the adapter. |
| 5 | Testable? | Yes. Fetch is injected; 7 adapter/contract tests plus the fake. |
| 6 | Observable on failure? | Yes. Every failure has a class and `detail`, and the execution ref is persisted on the attempt. |
| 7 | Replaceable? | Yes. The contract has no imports, and a replacement test proves the domain shape is unchanged across adapters. |
| 8 | Privacy? | Only the extracted source text is sent (minimum necessary). Prompts are not logged. |
| 9 | Cost? | No bundle or cold-start overhead. Usage tokens are recorded per job. |
| 10 | Tomorrow? | The SDK or another adapter can be added behind the same contract when streaming/tools/multi-provider are admitted. |

## 5. Known limitations / debt

- Connection errors *before* send (for example DNS) are conservatively classed as `ambiguous`. A later refinement can separate
  provably-unsent errors as `retryable`.
- The cost of a failed-but-executed attempt (for example invalid output) is not recorded as a UsageEvent. Only successful jobs
  produce usage. This needs attempt-level cost events before real providers are used.
- The adapter targets the common OpenAI-compatible `json_schema` response format. Other vendors need their own adapter file.

## 6. D-034 / speech / evaluation reconciliation (CMD-0004 → CMD-0013, D-062)

No code changed for this section; the seam evidence above still holds.

| Question | Disposition |
| --- | --- |
| Structured generation provider-neutral? | **Yes (PASS for M4).** `StructuredGenerationCapability` is Learning App-owned and has no imports. No provider SDK type reaches the domain, the DB rows or the Flutter models. |
| Distinct language semantics representable? | **Yes.** `outputLocale` carries content/learning locale; uiLocale lives on `accounts.locale`; source and voice locale are additive columns later (LA-0011 §6). |
| Speech in M4 | **Implementation N/A_BY_SCOPE.** Architecture compatibility is assessed, and nothing is built. The base Learning Engine is voice-optional (D-042). Speech is Sesli Öğren product-local (D-062). No SpeechProvider, shared Speech Service or shared-runtime speech extraction is required, and their absence is **not** debt. |
| Future Speech Capability boundary | **FUTURE_COMPATIBLE, with additive MIGRATION_DEBT before provider lock-in (D-062).** The same shape as this seam applies: a product-owned contract with no imports, a deterministic fake, one adapter file per provider, a server-side call so no credential reaches the client, and usage/cost recorded per job. It is compatible with voice-profile/language separation and later streaming, chunking and caching. Speech output would be a job-produced artifact, so the job/idempotency/ambiguous-dispatch rules carry over unchanged. |
| Evaluation readiness | **Attachment point exists; no framework added.** Deterministic fake output, typed validation (`la_valid_summary_content`), `content_schema_version` and `execution_ref` make eval datasets/runners attachable and replaceable later. |
| Duplicate generic AI/speech/eval control plane? | **None created.** The spike has one narrow generation contract and one adapter. Routing/fallback, telemetry, gateway and eval execution are not built inside Learning, so a later shared runtime can own them. |
