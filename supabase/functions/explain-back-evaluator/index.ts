import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
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

function validUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function validAttemptId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_.:-]{8,128}$/.test(value);
}

function validHash(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return reply(405, "method_not_allowed");

  const authorization = request.headers.get("authorization") ?? "";
  const jwt = authorization.replace(/^Bearer\s+/i, "");
  if (!jwt || jwt === authorization) return reply(401, "authentication_required");

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return reply(400, "invalid_json");
  }

  const attemptId = body.attempt_id;
  const materialId = body.material_id;
  const sourceHash = body.source_content_hash;
  const rawResponse = body.response;
  const outputLocale = typeof body.output_locale === "string"
    ? body.output_locale.trim()
    : "tr-TR";

  if (!validAttemptId(attemptId)) return reply(400, "invalid_attempt_id");
  if (!validUuid(materialId)) return reply(400, "invalid_material_id");
  if (!validHash(sourceHash)) return reply(400, "invalid_source_hash");
  if (typeof rawResponse !== "string") return reply(400, "invalid_response");
  const learnerResponse = rawResponse.trim();
  if (learnerResponse.length < 1 || learnerResponse.length > 2000) {
    return reply(400, "invalid_response");
  }
  if (outputLocale.length < 2 || outputLocale.length > 32) {
    return reply(400, "invalid_output_locale");
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const publishableKey = envKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
  const serviceKey = envKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  const providerKey = Deno.env.get("LEARNING_AI_API_KEY") ?? "";
  const model = Deno.env.get("LEARNING_AI_MODEL") ?? "";
  const base = Deno.env.get("LEARNING_AI_BASE_URL") ?? "https://api.openai.com/v1";

  if (!url || !publishableKey || !serviceKey || !providerKey || !model || !base.startsWith("https://")) {
    return reply(503, "evaluator_not_configured");
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

  const responseDigest = await sha256Hex(learnerResponse);
  const { error: openError } = await userDb.rpc("open_explain_back_attempt", {
    p_attempt_id: attemptId,
    p_material_id: materialId,
    p_source_content_hash: sourceHash,
    p_response_digest: responseDigest,
    p_response_length: learnerResponse.length,
  });
  if (openError) {
    const message = openError.message ?? "";
    if (message.includes("stale_source")) return reply(409, "stale_source");
    if (message.includes("material_not_found") || message.includes("source_unavailable")) {
      return reply(404, "source_unavailable");
    }
    if (message.includes("attempt_id_reused")) return reply(409, "attempt_id_reused");
    return reply(502, "attempt_open_failed");
  }

  const db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const rpc = async (name: string, params: Record<string, unknown>) => {
    const { data, error } = await db.rpc(name, params);
    if (error) throw new Error(name + ":" + error.code + ":" + error.message);
    return data;
  };

  let claim: Record<string, unknown> | null = null;
  try {
    const result = await rpc("claim_explain_back_attempt", {
      p_account_id: user.id,
      p_attempt_id: attemptId,
      p_lease_seconds: 120,
    });
    claim = Array.isArray(result) ? (result[0] ?? null) : result;
  } catch (error) {
    if (error instanceof Error && error.message.includes("quota_exceeded")) {
      return reply(429, "quota_exceeded");
    }
    return reply(502, "claim_failed");
  }

  if (!claim) {
    const { data: existing } = await db
      .from("explain_back_attempts")
      .select("evaluation_state,evaluation_kind")
      .eq("account_id", user.id)
      .eq("attempt_id", attemptId)
      .maybeSingle();
    if (existing?.evaluation_state === "SUCCEEDED") return reply(200, "succeeded");
    if (existing?.evaluation_state === "PROCESSING") return reply(202, "processing");
    if (existing?.evaluation_state === "RECONCILIATION_REQUIRED") {
      return reply(200, "reconciliation_required");
    }
    if (existing?.evaluation_state === "FAILED_FINAL") return reply(200, "failed_final");
    return reply(200, "not_runnable");
  }

  const leaseToken = String(claim.lease_token);
  const sourceText = String(claim.source_text ?? "");
  if (!sourceText.trim()) {
    try {
      await rpc("fail_explain_back_attempt", {
        p_account_id: user.id,
        p_attempt_id: attemptId,
        p_lease_token: leaseToken,
        p_failure_class: "final",
        p_provider_ref: null,
      });
    } catch {
      // Preserve the original fail-closed response.
    }
    return reply(200, "failed_final");
  }

  try {
    await rpc("mark_explain_back_dispatched", {
      p_account_id: user.id,
      p_attempt_id: attemptId,
      p_lease_token: leaseToken,
      p_adapter_ref: "fetch-chat:" + model,
    });
  } catch {
    return reply(502, "dispatch_state_failed");
  }

  let failure: "retryable" | "final" | "ambiguous" = "ambiguous";
  let providerRef: string | null = null;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 60000);
    let response: Response;
    try {
      response = await fetch(base.replace(/\/$/, "") + "/chat/completions", {
        method: "POST",
        signal: controller.signal,
        headers: {
          authorization: "Bearer " + providerKey,
          "content-type": "application/json",
          "idempotency-key": "explain-back:" + user.id + ":" + attemptId,
        },
        body: JSON.stringify({
          model,
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "explain_back_v1",
              strict: true,
              schema: {
                type: "object",
                additionalProperties: false,
                required: ["evaluation_kind", "feedback", "targeted_repair"],
                properties: {
                  evaluation_kind: {
                    type: "string",
                    enum: ["sufficient", "gap_detected", "not_evaluable"],
                  },
                  feedback: { type: "string" },
                  targeted_repair: { type: "string" },
                },
              },
            },
          },
          messages: [
            {
              role: "system",
              content:
                "Evaluate the learner's explanation only against the supplied source. Do not infer mastery. Be conservative. Use not_evaluable when the response is too vague or cannot be grounded. If there is a gap, give one specific repair. Respond in " +
                outputLocale +
                " using the required JSON.",
            },
            {
              role: "user",
              content: JSON.stringify({
                source: sourceText,
                learner_response: learnerResponse,
              }),
            },
          ],
        }),
      });
    } finally {
      clearTimeout(timer);
    }

    providerRef = response.headers.get("x-request-id");
    if (!response.ok) {
      failure = [408, 409, 429].includes(response.status) || response.status >= 500
        ? "retryable"
        : "final";
    } else {
      const providerBody = await response.json();
      providerRef = providerRef ?? (typeof providerBody?.id === "string" ? providerBody.id : null);
      const content = JSON.parse(providerBody?.choices?.[0]?.message?.content ?? "null");
      const kind = content?.evaluation_kind;
      const feedback = typeof content?.feedback === "string" ? content.feedback.trim() : "";
      const repair = typeof content?.targeted_repair === "string"
        ? content.targeted_repair.trim()
        : "";
      if (
        ["sufficient", "gap_detected", "not_evaluable"].includes(kind) &&
        feedback.length >= 1 &&
        feedback.length <= 4000 &&
        repair.length <= 4000
      ) {
        try {
          await rpc("complete_explain_back_attempt", {
            p_account_id: user.id,
            p_attempt_id: attemptId,
            p_lease_token: leaseToken,
            p_evaluation_kind: kind,
            p_evaluator_ref: providerRef ?? ("model:" + model),
            p_feedback: feedback,
            p_targeted_repair: repair,
          });
          return reply(200, "succeeded");
        } catch {
          return reply(502, "completion_not_confirmed");
        }
      }
      failure = "final";
    }
  } catch {
    failure = "ambiguous";
  }

  try {
    const state = await rpc("fail_explain_back_attempt", {
      p_account_id: user.id,
      p_attempt_id: attemptId,
      p_lease_token: leaseToken,
      p_failure_class: failure,
      p_provider_ref: providerRef,
    });
    if (state === "RECONCILIATION_REQUIRED") return reply(200, "reconciliation_required");
    if (state === "FAILED_RETRYABLE") return reply(200, "failed_retryable");
    return reply(200, "failed_final");
  } catch {
    return reply(502, "failure_not_confirmed");
  }
});
