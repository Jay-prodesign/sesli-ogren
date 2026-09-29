# LA-0013 / LA-0014 / LA-0015 — End-to-end flow, tenant isolation, job idempotency

- Tasks: [LA-0013](../../exec-plans/LA-0013.md) · [LA-0014](../../exec-plans/LA-0014.md) · [LA-0015](../../exec-plans/LA-0015.md) · Date: 2026-09-29
- Runtime evidence: PostgreSQL 16.13 with the Supabase shim, Deno 2.9.7, Flutter 3.47.5 / Dart 3.13.4.
  Reproduce with `spike/architecture-proof/db/run_sql_suite.sh`, `deno test -A` and `flutter test` as described in
  [`spike/architecture-proof/README.md`](../../../spike/architecture-proof/README.md).

## LA-0013 — Authenticated Material → Summary Artifact (bounded proof)

| Step | Proven by |
| --- | --- |
| Authenticated user → account | `auth.users` insert creates `accounts` + `entitlements` (trigger); test `10_canonical_flow.sql` |
| Material → SourceAsset → ExtractedContent | `create_text_material` RPC. The source is hashed; extraction is derived and versioned (`10_canonical_flow.sql`) |
| GenerationJob QUEUED → PROCESSING → SUCCEEDED | `request_summary` → `claim_generation_job` → `mark_attempt_dispatched` → `complete_generation_attempt` (`10_…`) |
| Deterministic Summary via the provider seam | Deno worker + `DeterministicFakeProvider` against the real DB (`worker_test.ts` integration) |
| Persistent Summary **Artifact** (not a string) | `artifacts` row with version, job/attempt lineage, `AI_GENERATED` trust class, and EvidenceRef. `materials` has **no** summary column (asserted) |
| Library projection | `library_items` view points at the latest available artifact (`10_…`) |
| Reopen from persistence | A separate psql session (`11_canonical_flow_reopen.sql`) plus a fresh Deno connection re-read everything |
| Client contract | Flutter `la_spike_client`: canonical Dart models decode the **actual owner-visible rows** captured from the DB (`test/fixtures/owner_rows.json`); job state → queued/processing/success/failure/retry mapping; proof-only status card (D-028 label) |

Results: SQL **4/4** files pass. Deno **13/13** tests pass, including the DB integration. Flutter **5/5** tests pass and `flutter analyze` is clean.

Not proven here (debt, see LA-0016/LA-0017): live Supabase PostgREST/GoTrue HTTP path (shim only), PDF/OCR
extraction (pasted text only), real provider call, and the donor Flutter app wired to the canonical tables.

## LA-0014 — Tenant / RLS / storage isolation (`20_tenant_isolation.sql`)

| Case | Result |
| --- | --- |
| `anon` reads materials/artifacts/library, calls RPCs | denied (`permission denied`) |
| `authenticated` without a subject claim | RPC raises `not_authenticated` |
| User B reads every canonical table + library + artifact by id | 0 rows everywhere; sees only own account |
| B direct UPDATE/DELETE/INSERT (forged `account_id`) | denied (client SELECT-only grants) |
| B `request_summary` / `retry` / `delete` on A's IDs | `material_not_found` / `job_not_found`. The error is identical to the one for a nonexistent ID (**non-revealing**) |
| Idempotency key namespace | Per account: B reusing A's key string gets B's own job |
| Worker RPCs (`claim`, `complete`, `reconcile`) from a client | denied |
| Storage: list / write into A's prefix / delete A's object | 0 rows / RLS violation / no-op (A's object survives) |
| Secret boundary | no secret-like columns; clients cannot read or write `lease_token` (column grants) |
| Deletion | owner's material, artifact, source, extraction and library entry all disappear; generation from a deleted material is refused |

Mutation check: replacing the artifact owner policy with `using (true)` makes this test **fail**, which confirms the test detects a broken policy.

## LA-0015 — GenerationJob retry / idempotency / lineage (`30_job_idempotency.sql`, Deno integration)

| Invariant | Evidence |
| --- | --- |
| Same key → same job | asserted |
| Same request with a **new** key → same live job (no duplicate billable output) | fingerprint + unique partial index `generation_jobs_one_live_initial` |
| Key reused on a different material → rejected | `idempotency_key_reused` |
| Retryable failure → no automatic re-dispatch; explicit user retry → attempt 2 linked to attempt 1; predecessor immutable | asserted in SQL and in the Deno integration test |
| Stale lease/token cannot mutate | `stale_lease` on late completion, duplicate completion, and old-token dispatch |
| Crash after dispatch (lease expiry) → **never auto-resent**; job waits in `reconciliation_required`; the user cannot blind-retry | asserted |
| Reconciliation from provider record → success without re-send; second reconciliation refused | asserted |
| Crash before dispatch → safe automatic re-run with a new linked attempt | asserted |
| One artifact per job; one UsageEvent per job; quota consumed once per successful job | asserted |
| Explicit regeneration → new job, new artifact version, previous superseded, quota consumed | asserted |
| Server-side quota enforcement | `quota_exceeded` |

Mutation checks: removing the RPC fingerprint dedupe is still caught by the DB unique index (defence in depth).
Making expired *dispatched* leases re-runnable makes the test **fail**.

## D-029 Final Engineering Test — idempotency-key design

| # | Answer |
| --- | --- |
| 1 Necessary | Yes. It is a Handoff acceptance criterion (no duplicate billable generation). |
| 2 Simplest | Client key + server fingerprint + one partial unique index; attempt key = `job_id:n`. No distributed lock or queue service. |
| 3 Secure | Keys are namespaced per account; errors are non-revealing; worker-only RPCs. |
| 4 Understandable | Seven job states from the canonical contract; `dispatch_state` names the ambiguity explicitly. |
| 5 Testable | 11 scenario groups in SQL plus the Deno integration test. |
| 6 Observable | `failure_class`, `dispatch_state`, `budget_effect`, and `attempt_number` are queryable by the owner and operators. |
| 7 Evolvable | New artifact types reuse the same job and attempt tables. |
| 8 Privacy | No content in keys or fingerprints (hash only). |
| 9 Cost | Prevents duplicate provider spend by construction. |
| 10 Tomorrow | Attempt-level cost events and provider-side idempotency are additive later. |
