// Minimal direct-HTTP adapter for OpenAI-compatible chat-completions endpoints (LA-0012).
//
// Dependency-free (platform fetch only), so it runs unchanged on Supabase Edge (Deno).
// Provider request/response shapes stay inside this file; the domain sees only
// GenerationResult. The API key is read server-side by the caller and passed in; it is never
// logged, persisted, or returned. No live provider is called in the spike (tests inject fetch).

import {
  type FailureClass,
  type GenerationRequest,
  type GenerationResult,
  type StructuredGenerationCapability,
  validateSummaryOutput,
} from "./contract.ts";

export interface FetchAdapterConfig {
  baseUrl: string; // e.g. https://provider.example/v1 (vendor chosen later; not decided by the spike)
  apiKey: string;
  model: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

const SUMMARY_SCHEMA = {
  name: "summary_v1",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["summary", "key_points", "language"],
    properties: {
      summary: { type: "string" },
      key_points: { type: "array", items: { type: "string" }, maxItems: 30 },
      language: { type: "string" },
    },
  },
};

function classifyHttp(status: number): FailureClass {
  if (status === 408 || status === 409 || status === 429 || status >= 500) return "retryable";
  return "final";
}

type ResolvedConfig = Required<FetchAdapterConfig>;

export class FetchChatCompletionsAdapter implements StructuredGenerationCapability {
  readonly adapterRef: string;
  #cfg: ResolvedConfig;

  constructor(cfg: FetchAdapterConfig) {
    if (!cfg.apiKey) throw new Error("missing_provider_credential");
    this.#cfg = { timeoutMs: 60_000, fetchImpl: fetch, ...cfg };
    this.adapterRef = `fetch-chat:${cfg.model}`;
  }

  async generate(request: GenerationRequest): Promise<GenerationResult> {
    const started = performance.now();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.#cfg.timeoutMs);
    let response: Response;
    try {
      response = await this.#cfg.fetchImpl(`${this.#cfg.baseUrl}/chat/completions`, {
        method: "POST",
        signal: controller.signal,
        headers: {
          "authorization": `Bearer ${this.#cfg.apiKey}`,
          "content-type": "application/json",
          "idempotency-key": request.attemptKey,
        },
        body: JSON.stringify({
          model: this.#cfg.model,
          response_format: { type: "json_schema", json_schema: SUMMARY_SCHEMA },
          messages: [
            {
              role: "system",
              content: `Summarize the user's study material in ${request.outputLocale}. ` +
                "Use only the provided text. Return JSON matching the schema.",
            },
            { role: "user", content: request.sourceText },
          ],
        }),
      });
    } catch (_err) {
      // Timeout or disconnect after the request may have reached the provider: never auto-resend.
      return { kind: "failed", failureClass: "ambiguous", detail: "transport_error_after_send" };
    } finally {
      clearTimeout(timer);
    }

    const executionRef = response.headers.get("x-request-id") ?? undefined;
    if (!response.ok) {
      return {
        kind: "failed",
        failureClass: classifyHttp(response.status),
        executionRef,
        detail: `http_${response.status}`,
      };
    }
    // deno-lint-ignore no-explicit-any
    let body: any;
    try {
      body = await response.json();
    } catch {
      return { kind: "failed", failureClass: "ambiguous", executionRef, detail: "unreadable_response" };
    }
    let parsed: unknown = null;
    try {
      parsed = JSON.parse(body?.choices?.[0]?.message?.content ?? "null");
    } catch {
      parsed = null;
    }
    const output = validateSummaryOutput(parsed);
    // The provider executed (billable) but output is unusable: final for this attempt, surfaced to the user.
    if (!output) {
      return {
        kind: "failed",
        failureClass: "final",
        executionRef: executionRef ?? body?.id,
        detail: "invalid_output",
      };
    }
    return {
      kind: "ok",
      output,
      usage: { totalTokens: Number(body?.usage?.total_tokens ?? 0), costClass: "metered" },
      executionRef: executionRef ?? String(body?.id ?? "unknown"),
      latencyMs: Math.round(performance.now() - started),
    };
  }
}
