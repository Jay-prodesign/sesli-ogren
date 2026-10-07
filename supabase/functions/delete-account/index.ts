import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function namedKey(currentName: string, legacyName: string): string {
  const raw = Deno.env.get(currentName);
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, string>;
      if (parsed.default) return parsed.default;
    } catch {
      // Fall through to the legacy key while projects migrate to the new key model.
    }
  }
  return Deno.env.get(legacyName) ?? "";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json(401, { error: "not_authenticated" });
  }
  const jwt = authHeader.slice("Bearer ".length).trim();
  if (!jwt) return json(401, { error: "not_authenticated" });

  let payload: { confirmation?: string };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "invalid_json" });
  }
  if (payload.confirmation !== "DELETE_MY_ACCOUNT") {
    return json(400, { error: "confirmation_required" });
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const publishableKey = namedKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
  const secretKey = namedKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publishableKey || !secretKey) {
    console.error("delete-account: required Supabase function secrets are unavailable");
    return json(503, { error: "server_not_configured" });
  }

  const userClient = createClient(url, publishableKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const adminClient = createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser(jwt);
  if (userError || !user) {
    return json(401, { error: "not_authenticated" });
  }

  const { error: requestError } = await userClient.rpc("request_account_deletion");
  if (requestError) {
    console.error("delete-account: deletion intent failed", requestError.code);
    return json(409, { error: "deletion_intent_failed" });
  }

  const { data: sourceRows, error: sourceError } = await adminClient
    .from("source_assets")
    .select("storage_bucket,storage_path")
    .eq("account_id", user.id)
    .not("storage_path", "is", null);
  if (sourceError) {
    console.error("delete-account: source inventory failed", sourceError.code);
    return json(502, { error: "storage_inventory_failed" });
  }

  const byBucket = new Map<string, string[]>();
  for (const row of sourceRows ?? []) {
    const bucket = row.storage_bucket as string | null;
    const path = row.storage_path as string | null;
    if (!bucket || !path) continue;
    const paths = byBucket.get(bucket) ?? [];
    paths.push(path);
    byBucket.set(bucket, paths);
  }

  for (const [bucket, paths] of byBucket.entries()) {
    for (let index = 0; index < paths.length; index += 100) {
      const { error: removeError } = await adminClient.storage.from(bucket).remove(paths.slice(index, index + 100));
      if (removeError) {
        console.error("delete-account: storage removal failed", bucket, removeError.message);
        return json(502, { error: "storage_cleanup_failed" });
      }
    }
  }

  const { error: signOutError } = await userClient.auth.signOut({ scope: "global" });
  if (signOutError) {
    console.error("delete-account: session revocation failed", signOutError.message);
    return json(502, { error: "session_revocation_failed" });
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("delete-account: auth user deletion failed", deleteError.message);
    return json(502, { error: "auth_user_deletion_failed" });
  }

  return json(200, { deleted: true });
});
