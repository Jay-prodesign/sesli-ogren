// LA-0012/LA-0013 worker tests.
//  * Unit: in-memory WorkerDb fake checks cycle ordering (dispatch recorded before the provider call).
//  * Integration (runs when LA_TEST_DB names a database prepared by run_sql_suite.sh): the full
//    authenticated Material -> Summary Artifact flow orchestrated by this Deno worker against real
//    Postgres RPCs, including retry lineage and ambiguous-dispatch handling.
import { deepStrictEqual as assertEquals, ok as assert } from "node:assert/strict";
import { DeterministicFakeProvider } from "../_shared/generation/fake_provider.ts";
import type { ClaimedWork, WorkerDb } from "./worker.ts";
import { runOnce } from "./worker.ts";
import { PsqlWorkerDb } from "./psql_worker_db.ts";

class MemoryDb implements WorkerDb {
  log: string[] = [];
  queue: ClaimedWork[] = [];
  claim() {
    this.log.push("claim");
    return Promise.resolve(this.queue.shift() ?? null);
  }
  markDispatched(_a: string, _t: string, ref: string) {
    this.log.push(`dispatched:${ref}`);
    return Promise.resolve();
  }
  complete(_a: string, _t: string, content: Record<string, unknown>) {
    this.log.push(`complete:${JSON.stringify(Object.keys(content).sort())}`);
    return Promise.resolve("artifact-1");
  }
  fail(_a: string, _t: string, cls: string) {
    this.log.push(`fail:${cls}`);
    return Promise.resolve("FAILED_RETRYABLE");
  }
}

const WORK: ClaimedWork = {
  jobId: "j1",
  attemptId: "a1",
  leaseToken: "t1",
  attemptIdempotencyKey: "j1:1",
  generationContract: "summary.v1",
  normalizedText: "Bir. İki.",
};

Deno.test("worker: idle when nothing is queued", async () => {
  assertEquals(await runOnce(new MemoryDb(), new DeterministicFakeProvider()), { kind: "idle" });
});

Deno.test("worker: records dispatch before calling the provider, then completes", async () => {
  const db = new MemoryDb();
  db.queue.push(WORK);
  const provider = new DeterministicFakeProvider();
  const out = await runOnce(db, provider);
  assertEquals(out, { kind: "succeeded", jobId: "j1", artifactId: "artifact-1" });
  assertEquals(db.log, ["claim", "dispatched:fake:deterministic-v1", 'complete:["key_points","language","summary"]']);
  assertEquals(provider.calls[0].attemptKey, "j1:1");
});

Deno.test("worker: ambiguous provider outcome is reported as ambiguous (never retried in-process)", async () => {
  const db = new MemoryDb();
  db.queue.push(WORK);
  const provider = new DeterministicFakeProvider(["ambiguous"]);
  const out = await runOnce(db, provider);
  assert(out.kind === "failed" && out.failureClass === "ambiguous");
  assertEquals(provider.calls.length, 1);
  assertEquals(db.log.at(-1), "fail:ambiguous");
});

Deno.test("worker: unsupported contract fails final without calling the provider", async () => {
  const db = new MemoryDb();
  db.queue.push({ ...WORK, generationContract: "quiz.v9" });
  const provider = new DeterministicFakeProvider();
  const out = await runOnce(db, provider);
  assert(out.kind === "failed" && out.failureClass === "unsupported_contract");
  assertEquals(provider.calls.length, 0);
});

const TEST_DB = Deno.env.get("LA_TEST_DB");

Deno.test({
  name: "integration: authenticated Material -> Summary Artifact via Deno worker + real Postgres RPCs",
  ignore: !TEST_DB,
  async fn() {
    const db = new PsqlWorkerDb(TEST_DB!);
    const user = "d1000000-0000-4000-8000-0000000000d1";
    await db.admin(
      `update public.generation_jobs set state='CANCELLED', lease_token=null where state in ('QUEUED','PROCESSING');
                    insert into auth.users (id, email) values (:'u', 'deno-e2e@example.test') on conflict do nothing;`,
      { u: user },
    );
    const material = await db.asUser(user, `select public.create_text_material('Fotosentez', :'t');`, {
      t: "Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığı soğurur.",
    });
    const job = await db.asUser(user, `select public.request_summary(:'m', :'k');`, {
      m: material,
      k: `deno-e2e-${material.slice(0, 8)}`,
    });

    // Attempt 1: provider fails retryably; the user explicitly retries; attempt 2 succeeds.
    const provider = new DeterministicFakeProvider(["retryable"]);
    const first = await runOnce(db, provider);
    assert(first.kind === "failed" && first.jobState === "FAILED_RETRYABLE");
    assertEquals(await runOnce(db, provider), { kind: "idle" }, "failed job is not auto re-dispatched");
    await db.asUser(user, `select public.retry_generation_job(:'j');`, { j: job });
    const second = await runOnce(db, provider);
    assert(second.kind === "succeeded");

    // Reopen as the owner in a fresh connection: library projection + persisted artifact + lineage.
    const row = JSON.parse(
      await db.asUser(
        user,
        `select json_build_object(
        'state', (select state from public.generation_jobs where id = :'j'),
        'attempts', (select json_agg(json_build_object('n', attempt_number, 'status', status, 'pred', predecessor_attempt_id is not null) order by attempt_number) from public.generation_attempts where job_id = :'j'),
        'library', (select row_to_json(l) from public.library_items l where material_id = :'m'),
        'artifact', (select content from public.artifacts where generation_job_id = :'j'),
        'usage', (select count(*) from public.usage_events where generation_job_id = :'j'));`,
        { j: job, m: material },
      ),
    );
    assertEquals(row.state, "SUCCEEDED");
    assertEquals(row.attempts, [{ n: 1, status: "failed", pred: false }, { n: 2, status: "succeeded", pred: true }]);
    assertEquals(row.library.processing_state, "ready");
    assertEquals(row.library.summary_artifact_id, second.artifactId);
    assertEquals(
      row.artifact.summary,
      "Fotosentez ışık enerjisini kimyasal enerjiye dönüştürür. Klorofil ışığı soğurur.",
    );
    assertEquals(row.usage, 1);
    assertEquals(provider.calls.map((c) => c.attemptKey), [`${job}:1`, `${job}:2`]);

    // Another user cannot see any of it.
    const other = "d1000000-0000-4000-8000-0000000000d2";
    await db.admin(
      `insert into auth.users (id, email) values (:'u', 'deno-e2e-b@example.test') on conflict do nothing;`,
      { u: other },
    );
    assertEquals(await db.asUser(other, `select count(*) from public.library_items;`), "0");
    assertEquals(await db.asUser(other, `select count(*) from public.artifacts;`), "0");
  },
});
