// Deterministic fake StructuredGenerationCapability (LA-0012). No network, no credentials.
// Same input always yields the same output and execution reference, so tests and the
// end-to-end proof are reproducible. Failures can be scripted per call for retry tests.

import type { FailureClass, GenerationRequest, GenerationResult, StructuredGenerationCapability } from "./contract.ts";

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

export class DeterministicFakeProvider implements StructuredGenerationCapability {
  readonly adapterRef = "fake:deterministic-v1";
  readonly calls: GenerationRequest[] = [];
  #script: FailureClass[];

  /** `script`: failure classes returned by the first N calls, in order; later calls succeed. */
  constructor(script: FailureClass[] = []) {
    this.#script = [...script];
  }

  async generate(request: GenerationRequest): Promise<GenerationResult> {
    this.calls.push(request);
    const executionRef = `fake-${(await sha256Hex(request.attemptKey)).slice(0, 16)}`;
    const scripted = this.#script.shift();
    if (scripted) return { kind: "failed", failureClass: scripted, executionRef, detail: "scripted" };

    const sentences = request.sourceText.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
    const summary = sentences.slice(0, 2).join(" ") || request.sourceText.slice(0, 200);
    const keyPoints = sentences.slice(0, 5).map((s) => s.replace(/[.!?]+$/, "").slice(0, 80));
    return {
      kind: "ok",
      output: { summary, keyPoints, language: request.outputLocale },
      usage: { totalTokens: Math.ceil(request.sourceText.length / 4), costClass: "fake", estimatedCostUsd: 0 },
      executionRef,
      latencyMs: 0,
    };
  }
}
