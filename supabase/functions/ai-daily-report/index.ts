// ============================================================================
// ai-daily-report — WhatsApp-ready daily site summary (Linear AKS-76)
// ----------------------------------------------------------------------------
// Input  : { project_id: string, date?: string (yyyy-mm-dd),
//            language?: "en" | "hi", transcript?: string }
// Output : { summary: string, language, project_id, date }
//
// Flow: Flutter passes a project + date. This function fetches that day's
//       attendance + material movements (under the CALLER's RLS, so a user
//       only ever summarises their own company's data), feeds the numbers to
//       Gemini, and returns a short, friendly WhatsApp-style site report in
//       English or Hindi. If a voice `transcript` is supplied (voice report
//       flow), it is included as the site engineer's spoken notes.
//
// GEMINI_API_KEY is read from the Edge Function env. Never sent to Flutter.
// ============================================================================

import {
  callerClient,
  callGemini,
  handlePreflight,
  jsonResponse,
  requireCaller,
} from "../_shared/gemini.ts";

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
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

    const projectId: string | undefined = body.project_id;
    const date: string = (body.date as string) || todayIso();
    const language: "en" | "hi" = body.language === "hi" ? "hi" : "en";
    const transcript: string | undefined = body.transcript;

    if (!projectId) {
      return jsonResponse({ error: "project_id is required" }, 400);
    }

    // All reads use the caller's client -> RLS guarantees same-company scope.
    const db = callerClient(caller.authHeader);

    // Day window [date 00:00, date+1 00:00) for created_at-style columns.
    const dayStart = `${date}T00:00:00`;
    const dayEnd = `${date}T23:59:59`;

    // ── Project name (best-effort) ───────────────────────────────────────
    const { data: project } = await db
      .from("projects")
      .select("name")
      .eq("id", projectId)
      .maybeSingle();

    // ── Attendance for the day (best-effort; tolerate schema differences) ─
    let attendanceRows: Array<Record<string, unknown>> = [];
    {
      const { data } = await db
        .from("attendance")
        .select("*")
        .eq("project_id", projectId)
        .gte("date", date)
        .lte("date", date);
      attendanceRows = data ?? [];
    }
    const presentCount = attendanceRows.filter((r) => {
      const s = String(r["status"] ?? "").toLowerCase();
      return s === "present" || s === "p" || r["status"] == null;
    }).length;
    const totalWorkers = attendanceRows.length;

    // ── Material movements for the day (best-effort) ─────────────────────
    let materials: Array<Record<string, unknown>> = [];
    {
      const { data } = await db
        .from("material_transactions")
        .select("*")
        .eq("project_id", projectId)
        .gte("created_at", dayStart)
        .lte("created_at", dayEnd);
      materials = data ?? [];
    }

    const dataSnapshot = {
      project: project?.name ?? "Project",
      date,
      attendance: {
        total_marked: totalWorkers,
        present: presentCount,
      },
      materials: materials.map((m) => ({
        item: m["material_name"] ?? m["name"] ?? m["item"] ?? "Material",
        type: m["transaction_type"] ?? m["type"] ?? null,
        quantity: m["quantity"] ?? null,
        unit: m["unit"] ?? null,
      })),
    };

    const langInstruction = language === "hi"
      ? "Write the summary in simple, natural Hindi (Devanagari)."
      : "Write the summary in simple, professional English.";

    const systemPrompt =
      `You write short daily construction site reports for a builder to forward
on WhatsApp to the project owner. ${langInstruction}
Keep it under 120 words. Use a friendly tone, a date header, and short bullet
lines (use the • character). Cover: labour/attendance, materials received or
consumed, and any notes from the site engineer. Do NOT invent data — use only
what is provided. End with a one-line status.`;

    const userText = `Site data for the report (JSON):
${JSON.stringify(dataSnapshot, null, 2)}
${
        transcript
          ? `\nSite engineer's spoken notes (voice): "${transcript}"`
          : ""
      }`;

    const summary = await callGemini([{ text: userText }], {
      systemPrompt,
      temperature: 0.4,
    });

    return jsonResponse({
      summary: summary.trim(),
      language,
      project_id: projectId,
      date,
    });
  } catch (e) {
    if (e instanceof Response) return e;
    console.error("ai-daily-report error:", e);
    return jsonResponse({ error: "Failed to generate the report." }, 500);
  }
});
