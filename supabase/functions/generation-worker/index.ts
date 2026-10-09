import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, apikey, content-type, x-client-info, x-learning-worker-secret",
};

function envKey(name: string, legacy: string): string {
  const raw = Deno.env.get(name);
  if (raw) {
    try {
      const keys = JSON.parse(raw);
      if (typeof keys.default === "string") return keys.default;
    } catch {
      // Legacy/single-key environments fall through below.
    }
  }
  return Deno.env.get(legacy) ?? "";
}

function reply(status: number, code: string) {
  return new Response(JSON.stringify({ status: code }), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requestedJobId(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const value = (body as Record<string, unknown>).job_id;
  if (typeof value !== "string") return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return reply(405, "method_not_allowed");

  let body: unknown = null;
  try {
    body = await request.json();
  } catch {
    // Scheduler calls may intentionally omit a JSON body.
  }
  const targetJobId = requestedJobId(body);

  const workerSecret = Deno.env.get("LEARNING_WORKER_SECRET") ?? "";
  const suppliedWorkerSecret = request.headers.get("x-learning-worker-secret") ?? "";
  const schedulerAuthorized =
    workerSecret.length > 0 &&
    suppliedWorkerSecret.length > 0 &&
    suppliedWorkerSecret === workerSecret;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = envKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  const providerKey = Deno.env.get("LEARNING_AI_API_KEY") ?? "";
  const model = Deno.env.get("LEARNING_AI_MODEL") ?? "";
  const base =
    Deno.env.get("LEARNING_AI_BASE_URL") ?? "https://api.openai.com/v1";
  if (
    !url ||
    !serviceKey ||
    !providerKey ||
    !model ||
    !base.startsWith("https://")
  ) {
    return reply(503, "worker_not_configured");
  }

  if (!schedulerAuthorized) {
    if (!targetJobId) return reply(400, "job_id_required");
    const publishableKey = envKey(
      "SUPABASE_PUBLISHABLE_KEYS",
      "SUPABASE_ANON_KEY",
    );
    const authorization = request.headers.get("authorization") ?? "";
    const jwt = authorization.replace(/^Bearer\s+/i, "");
    if (!publishableKey || !jwt || jwt === authorization) {
      return reply(401, "authentication_required");
    }

    const userDb = createClient(url, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userDb.auth.getUser(jwt);
    if (userError || !user) return reply(401, "authentication_required");

    const { data: ownedJob, error: ownedJobError } = await userDb
      .from("generation_jobs")
      .select("id")
      .eq("id", targetJobId)
      .maybeSingle();
    if (ownedJobError || !ownedJob) return reply(404, "job_not_found");
  }

  const db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const rpc = async (name: string, params: Record<string, unknown>) => {
    const { data, error } = await db.rpc(name, params);
    if (error) throw new Error(name + ":" + error.code);
    return data;
  };

  let job: Record<string, unknown> | null = null;
  try {
    const result = targetJobId
      ? await rpc("claim_generation_job_by_id", {
          p_job_id: targetJobId,
          p_lease_seconds: 120,
        })
      : await rpc("claim_generation_job", { p_lease_seconds: 120 });
    job = Array.isArray(result) ? (result[0] ?? null) : result;
    if (!job) return reply(200, targetJobId ? "not_runnable" : "idle");

    const attempt = String(job.attempt_id);
    const lease = String(job.lease_token);
    if (job.generation_contract !== "summary.v1") {
      await rpc("fail_generation_attempt", {
        p_attempt_id: attempt,
        p_lease_token: lease,
        p_failure_class: "final",
        p_provider_ref: null,
      });
      return reply(200, "unsupported_contract");
    }

    await rpc("mark_attempt_dispatched", {
      p_attempt_id: attempt,
      p_lease_token: lease,
      p_adapter_ref: "fetch-chat:" + model,
    });

    let failure: "retryable" | "final" | "ambiguous" = "ambiguous";
    let providerRef: string | null = null;
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 60000);
      const started = performance.now();
      let response: Response;
      try {
        response = await fetch(
          base.replace(/\/$/, "") + "/chat/completions",
          {
            method: "POST",
            signal: controller.signal,
            headers: {
              authorization: "Bearer " + providerKey,
              "content-type": "application/json",
              "idempotency-key": String(job.attempt_idempotency_key),
            },
            body: JSON.stringify({
              model,
              response_format: {
                type: "json_schema",
                json_schema: {
                  name: "summary_v1",
                  strict: true,
                  schema: {
                    type: "object",
                    additionalProperties: false,
                    required: ["summary", "key_points", "language"],
                    properties: {
                      summary: { type: "string" },
                      key_points: {
                        type: "array",
                        items: { type: "string" },
                        maxItems: 30,
                      },
                      language: { type: "string" },
                    },
                  },
                },
              },
              messages: [
                {
                  role: "system",
                  content:
                    "Summarize the provided study material in Turkish. Use only the source text. Do not invent facts. Respond with the required JSON.",
                },
                { role: "user", content: String(job.normalized_text) },
              ],
            }),
          },
        );
      } finally {
        clearTimeout(timer);
      }

      providerRef = response.headers.get("x-request-id");
      if (!response.ok) {
        failure =
          [408, 409, 429].includes(response.status) ||
            response.status >= 500
            ? "retryable"
            : "final";
      } else {
        const providerBody = await response.json();
        providerRef =
          providerRef ??
          (typeof providerBody.id === "string" ? providerBody.id : null);
        const content = JSON.parse(
          providerBody?.choices?.[0]?.message?.content ?? "null",
        );
        if (
          typeof content?.summary === "string" &&
          content.summary.trim().length > 0 &&
          content.summary.length <= 20000 &&
          typeof content?.language === "string" &&
          content.language.length > 0 &&
          Array.isArray(content.key_points) &&
          content.key_points.length <= 30 &&
          content.key_points.every(
            (value: unknown) =>
              typeof value === "string" && value.trim().length > 0,
          )
        ) {
          try {
            await rpc("complete_generation_attempt", {
              p_attempt_id: attempt,
              p_lease_token: lease,
              p_content: content,
              p_provider_ref: providerRef ?? "unknown",
              p_usage: {
                total_tokens: Number(providerBody?.usage?.total_tokens ?? 0),
                cost_class: "metered",
              },
              p_latency_ms: Math.round(performance.now() - started),
            });
          } catch {
            console.error("generation-worker:completion_rpc_failed");
            return reply(502, "completion_not_confirmed");
          }
          return reply(200, "succeeded");
        }
        failure = "final";
      }
    } catch {
      // Ambiguous provider outcome: never automatically resend.
    }

    await rpc("fail_generation_attempt", {
      p_attempt_id: attempt,
      p_lease_token: lease,
      p_failure_class: failure,
      p_provider_ref: providerRef,
    });
    return reply(200, "failed");
  } catch (error) {
    console.error(
      "generation-worker:",
      error instanceof Error ? error.message.split(":")[0] : "unknown_error",
    );
    return reply(502, "worker_error");
  }
});
