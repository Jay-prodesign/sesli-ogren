// Learning App-owned structured-generation capability contract (LA-0012).
//
// Domain code depends only on these types. Provider SDK or HTTP shapes never appear here;
// adapters translate at the boundary. Mirrors V0_CANONICAL_DATA_CAPABILITY_CONTRACTS_v0.1 §16
// (StructuredGenerationCapability: task contract + authorized source + output schema ->
// typed result + evidence + usage).

export type GenerationTask = "summary.v1";

export interface GenerationRequest {
  task: GenerationTask;
  /** Stable per-attempt key; adapters forward it as the provider idempotency key when supported. */
  attemptKey: string;
  /** Minimum-necessary context: only the authorized, extracted source text. */
  sourceText: string;
  /** BCP-47 locale the output should be written in (D-034 contentLocale). */
  outputLocale: string;
}

export interface SummaryOutput {
  summary: string;
  keyPoints: string[];
  language: string;
}

export interface UsageReport {
  totalTokens: number;
  costClass: "fake" | "metered" | "unknown";
  estimatedCostUsd?: number;
}

export type FailureClass =
  /** Provider rejected or failed without executing billable work; safe to retry. */
  | "retryable"
  /** Request can never succeed as sent (bad input, policy refusal). */
  | "final"
  /** Request may have executed (timeout/disconnect after send); must be reconciled, never resent. */
  | "ambiguous";

export type GenerationResult =
  | { kind: "ok"; output: SummaryOutput; usage: UsageReport; executionRef: string; latencyMs: number }
  | { kind: "failed"; failureClass: FailureClass; executionRef?: string; detail: string };

export interface StructuredGenerationCapability {
  /** Opaque, non-secret identifier recorded on the attempt (e.g. "fake:deterministic-v1"). */
  readonly adapterRef: string;
  generate(request: GenerationRequest): Promise<GenerationResult>;
}

/** Validation shared by every adapter; mirrors SQL public.la_valid_summary_content. */
export function validateSummaryOutput(value: unknown): SummaryOutput | null {
  if (typeof value !== "object" || value === null) return null;
  const v = value as Record<string, unknown>;
  const summary = typeof v.summary === "string" ? v.summary.trim() : "";
  const language = typeof v.language === "string" ? v.language : "";
  const rawPoints = v.keyPoints ?? v.key_points;
  if (summary.length < 1 || summary.length > 20000 || language === "") return null;
  if (!Array.isArray(rawPoints) || rawPoints.length > 30) return null;
  if (!rawPoints.every((p) => typeof p === "string" && p.trim().length > 0)) return null;
  return { summary, keyPoints: rawPoints.map((p) => (p as string).trim()), language };
}

/** Wire shape persisted in artifacts.content (snake_case, schema version 1). */
export function toArtifactContent(o: SummaryOutput): Record<string, unknown> {
  return { summary: o.summary, key_points: o.keyPoints, language: o.language };
}
