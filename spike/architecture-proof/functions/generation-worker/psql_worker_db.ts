// Spike-harness WorkerDb: calls the service-role RPCs through the local `psql` client.
// Test/harness only (no Postgres driver dependency). Production uses the Supabase service client.
// Values are passed as psql variables (:'name'), which psql quotes as SQL literals.

import type { ClaimedWork, WorkerDb } from "./worker.ts";

export class PsqlWorkerDb implements WorkerDb {
  constructor(private readonly database: string) {}

  async #query(sql: string, vars: Record<string, string> = {}, role: string | null = "service_role"): Promise<string> {
    const args = ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", this.database];
    for (const [k, v] of Object.entries(vars)) args.push("-v", `${k}=${v}`);
    const cmd = new Deno.Command("psql", {
      args,
      stdin: "piped",
      stdout: "piped",
      stderr: "piped",
      env: role ? { PGOPTIONS: `-c role=${role}` } : {},
    });
    const child = cmd.spawn();
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode(sql));
    await writer.close();
    const { code, stdout, stderr } = await child.output();
    if (code !== 0) throw new Error(new TextDecoder().decode(stderr).trim());
    return new TextDecoder().decode(stdout).trim();
  }

  async claim(leaseSeconds: number): Promise<ClaimedWork | null> {
    const out = await this.#query(
      `select row_to_json(c) from public.claim_generation_job(:'lease') c;`,
      { lease: String(leaseSeconds) },
    );
    if (!out) return null;
    const r = JSON.parse(out);
    return {
      jobId: r.job_id,
      attemptId: r.attempt_id,
      leaseToken: r.lease_token,
      attemptIdempotencyKey: r.attempt_idempotency_key,
      generationContract: r.generation_contract,
      normalizedText: r.normalized_text,
    };
  }

  async markDispatched(attemptId: string, leaseToken: string, adapterRef: string): Promise<void> {
    await this.#query(`select public.mark_attempt_dispatched(:'a', :'t', :'r');`, {
      a: attemptId,
      t: leaseToken,
      r: adapterRef,
    });
  }

  async complete(
    attemptId: string,
    leaseToken: string,
    content: Record<string, unknown>,
    providerRef: string,
    usage: Record<string, unknown>,
    latencyMs: number,
  ): Promise<string> {
    return await this.#query(
      `select public.complete_generation_attempt(:'a', :'t', :'c'::jsonb, :'p', :'u'::jsonb, :'l');`,
      {
        a: attemptId,
        t: leaseToken,
        c: JSON.stringify(content),
        p: providerRef,
        u: JSON.stringify(usage),
        l: String(latencyMs),
      },
    );
  }

  async fail(attemptId: string, leaseToken: string, failureClass: string, providerRef: string | null): Promise<string> {
    return await this.#query(`select public.fail_generation_attempt(:'a', :'t', :'f', nullif(:'p', ''));`, {
      a: attemptId,
      t: leaseToken,
      f: failureClass,
      p: providerRef ?? "",
    });
  }

  /** Test helper: run SQL as an authenticated user (sets the JWT subject claim). */
  async asUser(userId: string, sql: string, vars: Record<string, string> = {}): Promise<string> {
    return await this.#query(
      `select set_config('request.jwt.claim.sub', :'uid', false) \\g /dev/null\n${sql}`,
      { uid: userId, ...vars },
      "authenticated",
    );
  }

  async admin(sql: string, vars: Record<string, string> = {}): Promise<string> {
    return await this.#query(sql, vars, null);
  }
}
