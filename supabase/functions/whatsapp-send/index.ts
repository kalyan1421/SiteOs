// ============================================================
// whatsapp-send — SiteOS WhatsApp Integration (Phase 1)  [Linear: AKS-71]
// ============================================================
// Sends a WhatsApp **template** message via the Meta WhatsApp Cloud API and
// records the attempt in `whatsapp_logs`.
//
// REQUIRED ENV / SECRETS (set with `supabase secrets set ...`):
//   WHATSAPP_PHONE_NUMBER_ID   — the Cloud API phone-number id (NOT the number)
//   WHATSAPP_ACCESS_TOKEN      — a permanent System User access token from Meta
//   SUPABASE_URL               — auto-injected by the platform
//   SUPABASE_ANON_KEY          — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY  — auto-injected (used to write whatsapp_logs)
//
// PREREQUISITES (Meta side — done once, manually):
//   1. A Meta WhatsApp Business Account + a registered phone number.
//   2. Each `template` you pass MUST be a message template that has been
//      SUBMITTED AND APPROVED in the Meta Business Manager. Sending an
//      unapproved/unknown template name returns a 400 from Meta.
//   3. The template's body placeholders ({{1}}, {{2}}, ...) map 1:1, in order,
//      to the `params` array sent in the request.
//
// Request body (POST, JSON), two modes:
//   A) Single send (e.g. the "send test" button from the app):
//        { "template": "daily_report", "to": "+919876543210",
//          "params": ["Skyline Towers", "5", "12 Apr 2026"],
//          "language": "en"  // optional, defaults to "en"
//        }
//   B) Cron fan-out (called by pg_cron at 19:00 IST — see 057_whatsapp.sql):
//        { "mode": "daily_report_cron" }
//      Iterates companies with whatsapp_preferences.daily_report_enabled = TRUE
//      and sends the "daily_report" template to each recipient.
// ============================================================

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// The supabase-js generic schema typing across esm.sh doesn't unify cleanly
// when a client is passed to a helper, so the helpers below accept a loosely
// typed client. This mirrors the existing create-site-manager function and has
// no runtime effect (the platform deploys functions without strict checking).
type AnyClient = any;

const ALLOWED_ORIGIN = Deno.env.get("SUPABASE_URL") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GRAPH_API_VERSION = "v21.0";
const DEFAULT_TEMPLATE = "daily_report";
const DEFAULT_LANGUAGE = "en";

interface RecipientResult {
  to: string;
  status: "sent" | "failed";
  error?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Normalise to a Meta-friendly number: digits only (drops "+", spaces, dashes). */
function normalisePhone(raw: string): string {
  return (raw ?? "").replace(/[^\d]/g, "");
}

/**
 * Calls the Meta Cloud API to send one template message.
 * Returns { ok, response|error }. Does NOT throw — callers log either way.
 */
async function sendTemplate(opts: {
  phoneNumberId: string;
  accessToken: string;
  to: string;
  template: string;
  language: string;
  params: string[];
}): Promise<{ ok: boolean; data: unknown }> {
  const url =
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${opts.phoneNumberId}/messages`;

  const components =
    opts.params.length > 0
      ? [
          {
            type: "body",
            parameters: opts.params.map((p) => ({ type: "text", text: p })),
          },
        ]
      : [];

  const metaBody = {
    messaging_product: "whatsapp",
    to: normalisePhone(opts.to),
    type: "template",
    template: {
      name: opts.template,
      language: { code: opts.language },
      ...(components.length > 0 ? { components } : {}),
    },
  };

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${opts.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(metaBody),
    });
    const data = await res.json().catch(() => ({}));
    return { ok: res.ok, data };
  } catch (err) {
    return { ok: false, data: { error: String(err) } };
  }
}

/** Insert one audit row into whatsapp_logs. Best-effort; never throws. */
async function logSend(
  admin: AnyClient,
  row: {
    company_id: string;
    template: string;
    to: string;
    status: "sent" | "failed";
    payload: unknown;
  }
): Promise<void> {
  try {
    await admin.from("whatsapp_logs").insert({
      company_id: row.company_id,
      template: row.template,
      to: row.to,
      status: row.status,
      payload: row.payload,
      sent_at: row.status === "sent" ? new Date().toISOString() : null,
    });
  } catch (_) {
    // Logging failures must not break the send response.
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const accessToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");

  if (!phoneNumberId || !accessToken) {
    return json(
      {
        error:
          "WhatsApp is not configured. Set WHATSAPP_PHONE_NUMBER_ID and " +
          "WHATSAPP_ACCESS_TOKEN as edge-function secrets.",
      },
      503
    );
  }

  // service_role client — bypasses RLS to write logs / read preferences.
  const admin: AnyClient = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // ── Mode B: cron fan-out (daily report) ────────────────────────────────
  if (body.mode === "daily_report_cron") {
    const { data: prefs, error: prefsErr } = await admin
      .from("whatsapp_preferences")
      .select("company_id, recipients")
      .eq("daily_report_enabled", true);

    if (prefsErr) {
      return json({ error: prefsErr.message }, 500);
    }

    let sent = 0;
    let failed = 0;
    for (const pref of prefs ?? []) {
      const companyId = pref.company_id as string;
      const recipients = (pref.recipients as Array<{ phone?: string }>) ?? [];
      for (const r of recipients) {
        if (!r?.phone) continue;
        // NOTE: real daily-report params (project, % complete, date) should be
        // assembled here from daily_progress before sending. Phase 1 sends the
        // approved template shell so the pipeline can be verified end to end.
        const result = await sendTemplate({
          phoneNumberId,
          accessToken,
          to: r.phone,
          template: DEFAULT_TEMPLATE,
          language: DEFAULT_LANGUAGE,
          params: [],
        });
        await logSend(admin, {
          company_id: companyId,
          template: DEFAULT_TEMPLATE,
          to: r.phone,
          status: result.ok ? "sent" : "failed",
          payload: { request: { template: DEFAULT_TEMPLATE }, response: result.data },
        });
        result.ok ? sent++ : failed++;
      }
    }
    return json({ mode: "daily_report_cron", sent, failed });
  }

  // ── Mode A: single send (test / on-demand) ─────────────────────────────
  // Verify the caller and resolve their company_id for the log row.
  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user: caller },
    error: callerErr,
  } = await callerClient.auth.getUser();

  if (callerErr || !caller) {
    return json({ error: "Unauthorized" }, 401);
  }

  const { data: callerProfile } = await callerClient
    .from("user_profiles")
    .select("company_id")
    .eq("id", caller.id)
    .single();

  const companyId = callerProfile?.company_id as string | undefined;
  if (!companyId) {
    return json({ error: "No company found for caller" }, 403);
  }

  const template = (body.template as string) || DEFAULT_TEMPLATE;
  const to = body.to as string | undefined;
  const language = (body.language as string) || DEFAULT_LANGUAGE;
  const params = Array.isArray(body.params)
    ? (body.params as unknown[]).map((p) => String(p))
    : [];

  if (!to) {
    return json({ error: "'to' (recipient phone) is required" }, 400);
  }

  const result = await sendTemplate({
    phoneNumberId,
    accessToken,
    to,
    template,
    language,
    params,
  });

  await logSend(admin, {
    company_id: companyId,
    template,
    to,
    status: result.ok ? "sent" : "failed",
    payload: { request: { template, params }, response: result.data },
  });

  if (!result.ok) {
    return json(
      {
        ok: false,
        error: "Meta API rejected the message",
        details: result.data,
      },
      502
    );
  }

  const sendResult: RecipientResult = { to, status: "sent" };
  return json({ ok: true, result: sendResult, response: result.data });
});
