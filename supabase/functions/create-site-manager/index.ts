import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Restrict CORS to the app's own Supabase project URL.
// Supabase Edge Functions are only called from the mobile app (native HTTP),
// not from a browser, so wildcard origin is not needed. The Authorization
// header is already verified server-side for every request.
const ALLOWED_ORIGIN = Deno.env.get("SUPABASE_URL") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Poll until the user_profiles row exists (created by DB trigger after signup). */
async function waitForProfile(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
  maxWaitMs = 5000,
  intervalMs = 200
): Promise<boolean> {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    const { data } = await adminClient
      .from("user_profiles")
      .select("id")
      .eq("id", userId)
      .maybeSingle();
    if (data) return true;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  return false;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Verify caller is an admin
  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user: callerUser },
    error: callerError,
  } = await callerClient.auth.getUser();

  if (callerError || !callerUser) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: callerProfile } = await callerClient
    .from("user_profiles")
    .select("role")
    .eq("id", callerUser.id)
    .single();

  if (
    !callerProfile ||
    !["admin", "super_admin"].includes(callerProfile.role)
  ) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const body = await req.json();
  const { email, password, full_name, phone, position, address, role } = body;

  if (!email || !password) {
    return new Response(
      JSON.stringify({ error: "email and password are required" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  // Use service_role to create user — admin session is NEVER touched
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

  const { data: newUserData, error: createError } =
    await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, phone, position, address },
    });

  if (createError) {
    return new Response(JSON.stringify({ error: createError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const newUserId = newUserData.user.id;

  // Poll until the DB trigger creates the user_profiles row (max 5 s).
  const profileReady = await waitForProfile(adminClient, newUserId);
  if (!profileReady) {
    // Trigger did not fire in time; return partial success so the caller can
    // still display the new user — the profile will appear on next page load.
    return new Response(
      JSON.stringify({ user: { id: newUserId, email }, warning: "Profile not yet ready" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  const updates: Record<string, unknown> = {
    role: role ?? "site_manager",
    updated_at: new Date().toISOString(),
  };
  if (full_name) updates["full_name"] = full_name;
  if (phone) updates["phone"] = phone;
  if (position) updates["position"] = position;
  if (address) updates["address"] = address;

  const { data: updatedProfile, error: updateError } = await adminClient
    .from("user_profiles")
    .update(updates)
    .eq("id", newUserId)
    .select()
    .single();

  if (updateError) {
    return new Response(
      JSON.stringify({ user: { id: newUserId, email } }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  return new Response(JSON.stringify({ user: updatedProfile }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
