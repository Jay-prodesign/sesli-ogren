import { createClient } from "npm:@supabase/supabase-js@2.117.2";

// Server-only, single-job worker. Never expose the service key or provider key to Flutter.
// Invocation requires both Supabase JWT verification and a separate worker secret.
function secret(name: string, legacy: string): string {
  const raw = Deno.env.get(name);
  if (raw) {
    try { const keys = JSON.parse(raw); if (typeof keys.default === "string") return keys.default; } catch { /* legacy */ }
  }
  return Deno.env.get(legacy) ?? "";
}
function reply(status: number, code: string) {
  return new Response(JSON.stringify({ status: code }), { status, headers: { "content-type": "application/json" } });
}
Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, "method_not_allowed");
  const workerSecret = Deno.env.get("LEARNING_WORKER_SECRET") ?? "";
  const supplied = request.headers.get("x-learning-worker-secret") ?? "";
  if (!workerSecret || !supplied || supplied !== workerSecret) return reply(403, "worker_not_authorized");

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = secret("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  const providerKey = Deno.env.get("LEARNING_AI_API_KEY") ?? "";
  const model = Deno.env.get("LEARNING_AI_MODEL") ?? "";
  const base = Deno.env.get("LEARNING_AI_BASE_URL") ?? "https://api.openai.com/v1";
  if (!url || !serviceKey || !providerKey || !model || !base.startsWith("https://")) return reply(503, "worker_not_configured");

  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const rpc = async (name: string, params: Record<string, unknown>) => {
    const { data, error } = await db.rpc(name, params);
    if (error) throw new Error(name + ":" + error.code);
    return data;
  };
  let job: Record<string, unknown> | null = null;
  try {
    const result = await rpc("claim_generation_job", { p_lease_seconds: 120 });
    job = Array.isArray(result) ? (result[0] ?? null) : result;
    if (!job) return reply(200, "idle");
    const attempt = String(job.attempt_id);
    const lease = String(job.lease_token);
    if (job.generation_contract !== "summary.v1") {
      await rpc("fail_generation_attempt", { p_attempt_id: attempt, p_lease_token: lease, p_failure_class: "final", p_provider_ref: null });
      return reply(200, "unsupported_contract");
    }
    await rpc("mark_attempt_dispatched", { p_attempt_id: attempt, p_lease_token: lease, p_adapter_ref: "fetch-chat:" + model });
    let failure: "retryable" | "final" | "ambiguous" = "ambiguous";
    let providerRef: string | null = null;
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 60000);
      const started = performance.now();
      let response: Response;
      try {
        response = await fetch(base.replace(/\/$/, "") + "/chat/completions", {
          method: "POST", signal: controller.signal,
          headers: { authorization: "Bearer " + providerKey, "content-type": "application/json", "idempotency-key": String(job.attempt_idempotency_key) },
          body: JSON.stringify({
            model, response_format: { type: "json_schema", json_schema: { name: "summary_v1", strict: true, schema: {
              type: "object", additionalProperties: false, required: ["summary", "key_points", "language"],
              properties: { summary: { type: "string" }, key_points: { type: "array", items: { type: "string" }, maxItems: 30 }, language: { type: "string" } }
            } } },
            messages: [
              { role: "system", content: "Summarize the provided study material in Turkish. Use only the source text. Do not invent facts. Respond with the required JSON." },
              { role: "user", content: String(job.normalized_text) }
            ]
          })
        });
      } finally { clearTimeout(timer); }
      providerRef = response.headers.get("x-request-id");
      if (!response.ok) {
        failure = [408,409,429].includes(response.status) || response.status >= 500 ? "retryable" : "final";
      } else {
        const body = await response.json();
        providerRef = providerRef ?? (typeof body.id === "string" ? body.id : null);
        const content = JSON.parse(body?.choices?.[0]?.message?.content ?? "null");
        if (typeof content?.summary === "string" && content.summary.trim().length > 0 && content.summary.length <= 20000 &&
          typeof content?.language === "string" && content.language.length > 0 && Array.isArray(content.key_points) &&
          content.key_points.length <= 30 && content.key_points.every((x: unknown) => typeof x === "string" && x.trim().length > 0)) {
          // Database completion errors are not provider transport failures.
          // Never convert an RPC failure into an ambiguous provider failure.
          try {
            await rpc("complete_generation_attempt", {
              p_attempt_id: attempt, p_lease_token: lease, p_content: content,
              p_provider_ref: providerRef ?? "unknown", p_usage: { total_tokens: Number(body?.usage?.total_tokens ?? 0), cost_class: "metered" },
              p_latency_ms: Math.round(performance.now() - started)
            });
          } catch (error) {
            console.error("generation-worker:completion_rpc_failed");
            return reply(502, "completion_not_confirmed");
          }
          return reply(200, "succeeded");
        }
        failure = "final";
      }
    } catch { /* Ambiguous transport/provider outcome: never automatically resend. */ }
    await rpc("fail_generation_attempt", { p_attempt_id: attempt, p_lease_token: lease, p_failure_class: failure, p_provider_ref: providerRef });
    return reply(200, "failed");
  } catch (error) {
    console.error("generation-worker:", error instanceof Error ? error.message.split(":")[0] : "unknown_error");
    return reply(502, "worker_error");
  }
});
