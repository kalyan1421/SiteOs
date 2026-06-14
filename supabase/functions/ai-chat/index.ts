// ============================================================================
// ai-chat — Construction assistant chat over the company's own data (AKS-79)
// ----------------------------------------------------------------------------
// Input  : { question: string, language?: "en" | "hi", save?: boolean }
// Output : { answer: string, language }
//
// Flow: Flutter sends a question. This function runs a small set of SAFE,
//       pre-defined data lookups (read-only, under the CALLER's RLS so a user
//       only ever sees their own company's data), packs the results into a
//       compact context, and asks Gemini to answer using that context.
//       Optionally persists the turn to ai_chat_messages (migration 063).
//
// Security model: the model NEVER runs arbitrary SQL. Only the whitelisted
// snapshot functions below touch the database. GEMINI_API_KEY stays server-side.
// ============================================================================

import {
  callerClient,
  callGemini,
  handlePreflight,
  jsonResponse,
  requireCaller,
} from "../_shared/gemini.ts";

/**
 * SAFE pre-defined data functions. Each returns a small, read-only snapshot.
 * No user-controlled SQL — the model only ever sees the output, never queries.
 */
async function buildContext(
  authHeader: string,
): Promise<Record<string, unknown>> {
  const db = callerClient(authHeader);
  const ctx: Record<string, unknown> = {};

  // Active projects (count + a few names).
  try {
    const { data, count } = await db
      .from("projects")
      .select("name,status", { count: "exact" })
      .limit(10);
    ctx["projects"] = {
      total: count ?? (data?.length ?? 0),
      sample: (data ?? []).map((p) => ({
        name: p["name"],
        status: p["status"],
      })),
    };
  } catch (_) {
    ctx["projects"] = null;
  }

  // Recent material transactions (last 10).
  try {
    const { data } = await db
      .from("material_transactions")
      .select("material_name,transaction_type,quantity,unit,created_at")
      .order("created_at", { ascending: false })
      .limit(10);
    ctx["recent_materials"] = data ?? [];
  } catch (_) {
    ctx["recent_materials"] = null;
  }

  // Today's attendance headcount (best-effort).
  try {
    const today = new Date().toISOString().slice(0, 10);
    const { count } = await db
      .from("attendance")
      .select("id", { count: "exact", head: true })
      .gte("date", today)
      .lte("date", today);
    ctx["attendance_today"] = { marked: count ?? 0 };
  } catch (_) {
    ctx["attendance_today"] = null;
  }

  return ctx;
}

Deno.serve(async (req: Request) => {
  const pre = handlePreflight(req);
  if (pre) return pre;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const caller = await requireCaller(req);
    const body = await req.json().catch(() => ({}));

    const question: string = (body.question ?? "").toString().trim();
    const language: "en" | "hi" = body.language === "hi" ? "hi" : "en";
    const save: boolean = body.save === true;

    if (!question) {
      return jsonResponse({ error: "question is required" }, 400);
    }

    const context = await buildContext(caller.authHeader);

    const langInstruction = language === "hi"
      ? "Reply in simple, natural Hindi (Devanagari)."
      : "Reply in clear, concise English.";

    const systemPrompt =
      `You are SiteOS Assistant, a helpful construction-management copilot for an
Indian builder. ${langInstruction}
Answer the user's question using ONLY the company data snapshot provided below.
If the snapshot does not contain the answer, say so plainly and suggest where in
the SiteOS app they can find it (Projects, Attendance, Materials, Reports).
Be brief and practical. Never invent numbers.

COMPANY DATA SNAPSHOT (read-only):
${JSON.stringify(context, null, 2)}`;

    const answer = await callGemini([{ text: question }], {
      systemPrompt,
      temperature: 0.4,
    });
    const trimmed = answer.trim();

    // Optionally persist the conversation turn (best-effort, never blocks UX).
    if (save && caller.companyId) {
      try {
        const db = callerClient(caller.authHeader);
        await db.from("ai_chat_messages").insert([
          {
            company_id: caller.companyId,
            user_id: caller.userId,
            role: "user",
            content: question,
          },
          {
            company_id: caller.companyId,
            user_id: caller.userId,
            role: "assistant",
            content: trimmed,
          },
        ]);
      } catch (e) {
        console.error("ai-chat: failed to save history:", e);
      }
    }

    return jsonResponse({ answer: trimmed, language });
  } catch (e) {
    if (e instanceof Response) return e;
    console.error("ai-chat error:", e);
    return jsonResponse({ error: "Failed to get an answer." }, 500);
  }
});
