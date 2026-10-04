# M5 server database delta

This directory contains production-shaped M5 database changes that build on the
accepted M4 Architecture Proof canonical core.

During M5, the accepted base migrations remain:

1. `spike/architecture-proof/db/migrations/0001_canonical_core.sql`
2. `spike/architecture-proof/db/migrations/0002_generation_rpcs.sql`

Do not copy or fork those migrations just to rename the directory. The M5 delta
below is applied after them in the milestone validation batch:

3. `server/db/migrations/0003_recall_learning_truth.sql`

This is deliberate D-066/D-072 behavior: reuse accepted substrate, avoid a
second data authority, and batch the real PostgreSQL verification at the M5
checkpoint. No production database mutation is authorized here.
