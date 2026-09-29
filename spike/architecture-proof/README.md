# Architecture Proof (CLAUDE_HANDOFF_001) — spike code

This is proof-only code for the bounded V0 Architecture Spike. It is **not** the product app and it
is not merged. Evidence documents: [`docs/architecture/spike/`](../../docs/architecture/spike/).

| Path | Contents |
| --- | --- |
| `db/supabase_shim.sql` | A minimal Supabase platform surface (roles, `auth.uid()`, `storage.*`) for plain PostgreSQL 16. It is used because the Supabase CLI/Docker stack is unavailable in the build environment. |
| `db/migrations/` | Canonical Learning App schema (LA-0011) and generation RPCs (LA-0013–0015) |
| `db/tests/` | SQL proofs: flow, reopen, tenant isolation, idempotency |
| `db/run_sql_suite.sh`, `db/find_test_migration_step.sh` | Test runners, also used for the donor baseline (LA-0010) |
| `functions/` | Supabase Edge (Deno) generation seam, fake provider, fetch adapter, worker, and tests (LA-0012) |
| `client/` | Flutter contract package: canonical models and the proof-only status UI (LA-0013) |
| `evaluation/` | Dependency evaluations that are **not** product dependencies (Vercel AI SDK on Deno) |

## Reproduce

Prerequisites: PostgreSQL 16 server + `psql`, Deno ≥ 2.9, Flutter ≥ 3.47.

```sh
# 1. Local Postgres (any superuser works via PGADMIN); a Supabase-like "postgres" role is created by the shim.
export PGHOST=<socket dir or host> PGPORT=<port> PGADMIN=<superuser>
spike/architecture-proof/db/run_sql_suite.sh la_proof spike/architecture-proof/db/migrations spike/architecture-proof/db/tests

# 2. Deno seam + worker (+ DB integration when LA_TEST_DB is set)
cd spike/architecture-proof/functions && deno lint . && deno check . && LA_TEST_DB=la_proof deno test -A .

# 3. Flutter client contract
cd spike/architecture-proof/client && flutter pub get && flutter analyze && flutter test
```
