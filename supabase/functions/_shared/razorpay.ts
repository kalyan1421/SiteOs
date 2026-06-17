// ============================================================================
// _shared/razorpay.ts — Razorpay billing helpers (Deno) for the SaaS suite.
// ----------------------------------------------------------------------------
// Self-contained on purpose: billing must not depend on the AI module. Holds
// CORS/JSON/auth helpers plus Razorpay API + webhook-signature verification.
//
// SECURITY: RAZORPAY_KEY_SECRET and RAZORPAY_WEBHOOK_SECRET are read from the
// Edge Function environment ONLY. They are NEVER sent to the Flutter app.
//   supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=... \
//     RAZORPAY_WEBHOOK_SECRET=... RAZORPAY_PLAN_STARTER=plan_xxx \
//     RAZORPAY_PLAN_PRO=plan_xxx
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RAZORPAY_API = "https://api.razorpay.com/v1";

// Called from the native Flutter app (functions.invoke) and server-to-server by
// Razorpay — not a browser — so the origin allow-list can stay tight.
const ALLOWED_ORIGIN = Deno.env.get("SUPABASE_URL") ?? "*";

export const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-razorpay-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Standard CORS preflight handler. Returns a Response for OPTIONS, else null. */
export function handlePreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }
  return null;
}

export interface CallerContext {
  userId: string;
  companyId: string | null;
  authHeader: string;
}

/**
 * Verifies the request is from a signed-in user and resolves their company_id.
 * Throws a Response (caught by the function) on any auth failure.
 */
export async function requireCaller(req: Request): Promise<CallerContext> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw jsonResponse({ error: "Unauthorized" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const caller = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error } = await caller.auth.getUser();
  if (error || !user) throw jsonResponse({ error: "Unauthorized" }, 401);

  const { data: profile } = await caller
    .from("user_profiles")
    .select("company_id")
    .eq("id", user.id)
    .maybeSingle();

  return {
    userId: user.id,
    companyId: (profile?.company_id as string | null) ?? null,
    authHeader,
  };
}

/** Service-role client (bypasses RLS) — only for trusted server writes. */
export function adminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(supabaseUrl, serviceRoleKey);
}

// --- Plan mapping -----------------------------------------------------------

export type PlanKey = "starter" | "professional";

/** Monthly price in rupees, mirrors plan_features / the Flutter SiteOsPlan enum. */
export const PLAN_AMOUNT: Record<PlanKey, number> = {
  starter: 1999,
  professional: 4999,
};

/** Our plan key → the Razorpay plan id created in the dashboard (from env). */
export function razorpayPlanId(plan: PlanKey): string | null {
  const id = plan === "starter"
    ? Deno.env.get("RAZORPAY_PLAN_STARTER")
    : Deno.env.get("RAZORPAY_PLAN_PRO");
  return id && id.length > 0 ? id : null;
}

/** True when the Razorpay API credentials are present on the server. */
export function razorpayConfigured(): boolean {
  return !!Deno.env.get("RAZORPAY_KEY_ID") &&
    !!Deno.env.get("RAZORPAY_KEY_SECRET");
}

/** The publishable key id — safe to hand to the Flutter checkout. */
export function razorpayKeyId(): string {
  return Deno.env.get("RAZORPAY_KEY_ID") ?? "";
}

// --- Razorpay REST ----------------------------------------------------------

function authHeader(): string {
  const id = Deno.env.get("RAZORPAY_KEY_ID")!;
  const secret = Deno.env.get("RAZORPAY_KEY_SECRET")!;
  return "Basic " + btoa(`${id}:${secret}`);
}

/** Calls the Razorpay REST API with Basic auth. Throws a Response on failure. */
async function razorpayApi(
  path: string,
  method: "GET" | "POST",
  body?: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const res = await fetch(`${RAZORPAY_API}${path}`, {
    method,
    headers: {
      "Authorization": authHeader(),
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("Razorpay API error:", res.status, JSON.stringify(data));
    const msg = (data?.error?.description as string) ??
      `Razorpay request failed (${res.status}).`;
    throw jsonResponse({ error: msg }, 502);
  }
  return data as Record<string, unknown>;
}

export interface CreatedSubscription {
  rpSubId: string;
  shortUrl: string | null;
  status: string;
}

/**
 * Creates a Razorpay subscription for [plan]. `total_count` is the number of
 * billing cycles to authorise (12 monthly cycles ≈ one year before re-auth).
 */
export async function createRazorpaySubscription(
  plan: PlanKey,
  opts: { totalCount?: number; notes?: Record<string, string> } = {},
): Promise<CreatedSubscription> {
  const planId = razorpayPlanId(plan);
  if (!planId) {
    throw jsonResponse(
      { error: `No Razorpay plan configured for "${plan}".` },
      500,
    );
  }

  const sub = await razorpayApi("/subscriptions", "POST", {
    plan_id: planId,
    total_count: opts.totalCount ?? 12,
    customer_notify: 1,
    notes: opts.notes ?? {},
  });

  return {
    rpSubId: sub["id"] as string,
    shortUrl: (sub["short_url"] as string | undefined) ?? null,
    status: (sub["status"] as string | undefined) ?? "created",
  };
}

// --- Webhook signature verification ----------------------------------------

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time string compare to avoid signature timing leaks. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Verifies the `X-Razorpay-Signature` header against the RAW request body using
 * RAZORPAY_WEBHOOK_SECRET. Returns false (never throws) so the caller decides
 * the response. The raw body MUST be the exact bytes Razorpay sent — verify
 * BEFORE JSON.parse.
 */
export async function verifyWebhookSignature(
  rawBody: string,
  signature: string | null,
): Promise<boolean> {
  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!secret || !signature) return false;
  const expected = await hmacSha256Hex(secret, rawBody);
  return timingSafeEqual(expected, signature);
}
