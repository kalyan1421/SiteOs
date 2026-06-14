// ============================================================================
// _shared/gemini.ts — Gemini 1.5 Flash REST helpers (Deno) for the AI Suite.
// ----------------------------------------------------------------------------
// Every AI Edge Function imports from here so the key handling, CORS, and
// auth-verification logic live in ONE place.
//
// SECURITY: GEMINI_API_KEY is read from the Edge Function environment ONLY.
// It is NEVER sent to or stored in the Flutter app. Set it with:
//   supabase secrets set GEMINI_API_KEY=...
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Gemini 1.5 Flash — fast + cheap, supports text + vision (inline image data).
const GEMINI_MODEL = "gemini-1.5-flash";
const GEMINI_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

// Restrict CORS to the project's own URL. These functions are called from the
// native Flutter app (supabase.functions.invoke), not a browser, so a wildcard
// origin is unnecessary.
const ALLOWED_ORIGIN = Deno.env.get("SUPABASE_URL") ?? "";

export const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
  if (!authHeader) {
    throw jsonResponse({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Caller-scoped client — runs under the user's RLS, used to read their data.
  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error,
  } = await callerClient.auth.getUser();

  if (error || !user) {
    throw jsonResponse({ error: "Unauthorized" }, 401);
  }

  const { data: profile } = await callerClient
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

/** A caller-scoped Supabase client (respects the user's RLS). */
export function callerClient(authHeader: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  return createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
}

/** A service-role client (bypasses RLS) — use only for trusted server writes. */
export function adminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(supabaseUrl, serviceRoleKey);
}

export interface GeminiPart {
  text?: string;
  inlineData?: { mimeType: string; data: string };
}

export interface GeminiCallOptions {
  /** System / instruction prompt prepended as the first text part. */
  systemPrompt?: string;
  /** Force the model to return valid JSON (response_mime_type). */
  jsonMode?: boolean;
  /** 0.0–1.0; lower = more deterministic. Defaults to 0.2. */
  temperature?: number;
}

/**
 * Calls Gemini 1.5 Flash with the given parts and returns the raw text reply.
 * Reads GEMINI_API_KEY from the environment — throws a Response if it's missing.
 */
export async function callGemini(
  parts: GeminiPart[],
  opts: GeminiCallOptions = {},
): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    // Misconfiguration on the server — surface clearly, never leak the key.
    throw jsonResponse(
      { error: "AI is not configured. GEMINI_API_KEY is missing on the server." },
      500,
    );
  }

  const allParts: GeminiPart[] = [];
  if (opts.systemPrompt) allParts.push({ text: opts.systemPrompt });
  allParts.push(...parts);

  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts: allParts }],
    generationConfig: {
      temperature: opts.temperature ?? 0.2,
      ...(opts.jsonMode ? { responseMimeType: "application/json" } : {}),
    },
  };

  const url = `${GEMINI_BASE}/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error("Gemini API error:", res.status, detail);
    throw jsonResponse(
      { error: `AI request failed (${res.status}). Please try again.` },
      502,
    );
  }

  const data = await res.json();
  const text: string | undefined =
    data?.candidates?.[0]?.content?.parts
      ?.map((p: GeminiPart) => p.text ?? "")
      .join("") ?? undefined;

  if (!text) {
    console.error("Gemini returned no text:", JSON.stringify(data));
    throw jsonResponse({ error: "AI returned an empty response." }, 502);
  }
  return text;
}

/**
 * Parses a JSON string that may be wrapped in ```json ... ``` fences or have
 * leading/trailing prose. Returns the parsed object, or throws a 502 Response.
 */
export function parseJsonLoose<T>(raw: string): T {
  let s = raw.trim();
  // Strip markdown code fences if the model added them.
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  // Fall back to the first {...} or [...] block.
  if (!s.startsWith("{") && !s.startsWith("[")) {
    const obj = s.match(/[\{\[][\s\S]*[\}\]]/);
    if (obj) s = obj[0];
  }
  try {
    return JSON.parse(s) as T;
  } catch (_e) {
    console.error("Failed to parse AI JSON:", raw);
    throw jsonResponse(
      { error: "AI returned malformed data. Please try again." },
      502,
    );
  }
}
