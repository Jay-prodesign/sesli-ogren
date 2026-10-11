// Generation worker: one claim -> dispatch -> provider -> complete/fail cycle (LA-0012/LA-0013).
//
// The worker holds no domain authority: every state change goes through the service-role RPCs
// (claim_generation_job, mark_attempt_dispatched, complete_generation_attempt,
// fail_generation_attempt), which enforce the lease token and job/attempt invariants.

import { type StructuredGenerationCapability, toArtifactContent } from "../_shared/generation/contract.ts";

export interface ClaimedWork {
  jobId: string;
  attemptId: string;
  leaseToken: string;
  attemptIdempotencyKey: string;
  generationContract: string;
  normalizedText: string;
}

/** Port to the database RPCs. Production: supabase-js service client; spike harness: psql. */
export interface WorkerDb {
  claim(leaseSeconds: number): Promise<ClaimedWork | null>;
  markDispatched(attemptId: string, leaseToken: string, adapterRef: string): Promise<void>;
  complete(
    attemptId: string,
    leaseToken: string,
    content: Record<string, unknown>,
    providerRef: string,
    usage: Record<string, unknown>,
    latencyMs: number,
  ): Promise<string>;
  fail(attemptId: string, leaseToken: string, failureClass: string, providerRef: string | null): Promise<string>;
}

export type CycleOutcome =
  | { kind: "idle" }
  | { kind: "succeeded"; jobId: string; artifactId: string }
  | { kind: "failed"; jobId: string; jobState: string; failureClass: string };

export async function runOnce(
  db: WorkerDb,
  provider: StructuredGenerationCapability,
  opts: { leaseSeconds?: number; outputLocale?: string } = {},
): Promise<CycleOutcome> {
  const work = await db.claim(opts.leaseSeconds ?? 120);
  if (!work) return { kind: "idle" };
  if (work.generationContract !== "summary.v1") {
    const state = await db.fail(work.attemptId, work.leaseToken, "final", null);
    return { kind: "failed", jobId: work.jobId, jobState: state, failureClass: "unsupported_contract" };
  }

  // Record dispatch BEFORE calling the provider: from here on a crash is "ambiguous", never re-sent.
  await db.markDispatched(work.attemptId, work.leaseToken, provider.adapterRef);
  const result = await provider.generate({
    task: "summary.v1",
    attemptKey: work.attemptIdempotencyKey,
    sourceText: work.normalizedText,
    outputLocale: opts.outputLocale ?? "tr-TR",
  });

  if (result.kind === "ok") {
    const artifactId = await db.complete(
      work.attemptId,
      work.leaseToken,
      toArtifactContent(result.output),
      result.executionRef,
      {
        total_tokens: result.usage.totalTokens,
        cost_class: result.usage.costClass,
        estimated_cost_usd: result.usage.estimatedCostUsd ?? null,
      },
      result.latencyMs,
    );
    return { kind: "succeeded", jobId: work.jobId, artifactId };
  }
  const state = await db.fail(work.attemptId, work.leaseToken, result.failureClass, result.executionRef ?? null);
  return { kind: "failed", jobId: work.jobId, jobState: state, failureClass: result.failureClass };
}
