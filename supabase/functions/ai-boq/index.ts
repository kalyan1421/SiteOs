// ============================================================================
// ai-boq — AI Bill of Quantities generator (Linear AKS-78)
// ----------------------------------------------------------------------------
// Input  : {
//            project_type: string,   // "residential" | "commercial" | ...
//            area_sqft: number,
//            floors?: number,
//            quality?: "basic" | "standard" | "premium",
//            location?: string,      // city/region for rate context
//            notes?: string,
//            currency?: string       // default "INR"
//          }
// Output : { rows: BoqRow[], assumptions: string[], currency }
//          BoqRow = { category, description, unit, quantity, rate, amount }
//
// Flow: 3-step Flutter wizard collects params -> invoke this fn -> Gemini
//       returns estimated BOQ rows as JSON -> preview table in app.
// Estimates are indicative; the model is told to state its assumptions.
//
// GEMINI_API_KEY is read from the Edge Function env. Never sent to Flutter.
// ============================================================================

import {
  callGemini,
  handlePreflight,
  jsonResponse,
  parseJsonLoose,
  requireCaller,
} from "../_shared/gemini.ts";

const SYSTEM_PROMPT =
  `You are a senior quantity surveyor in India. Produce an indicative Bill of
Quantities (BOQ) for the described construction project using standard Indian
construction norms and current typical market rates (INR) for the given quality
tier and location. Group rows by category (e.g. Earthwork, RCC, Masonry,
Plastering, Flooring, Doors & Windows, Electrical, Plumbing, Painting, Finishing).

Return STRICT JSON with exactly this shape:
{
  "rows": [
    { "category": string, "description": string, "unit": string,
      "quantity": number, "rate": number, "amount": number }
  ],
  "assumptions": [ string ],   // key assumptions you made for the estimate
  "currency": "INR"
}
- amount MUST equal quantity * rate (rounded to whole rupees).
- All numbers plain (no symbols/commas).
- Provide 15-30 representative rows covering the major heads.
- This is an INDICATIVE estimate; reflect that in the assumptions.`;

Deno.serve(async (req: Request) => {
  const pre = handlePreflight(req);
  if (pre) return pre;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    await requireCaller(req);
    const body = await req.json().catch(() => ({}));

    const projectType: string = body.project_type ?? "residential";
    const areaSqft = Number(body.area_sqft);
    const floors = Number(body.floors ?? 1);
    const quality: string = body.quality ?? "standard";
    const location: string = body.location ?? "India";
    const notes: string = body.notes ?? "";
    const currency: string = body.currency ?? "INR";

    if (!areaSqft || areaSqft <= 0) {
      return jsonResponse(
        { error: "area_sqft is required and must be greater than 0" },
        400,
      );
    }

    const userText = `Generate a BOQ for:
- Project type: ${projectType}
- Built-up area: ${areaSqft} sq.ft
- Floors: ${floors}
- Quality tier: ${quality}
- Location: ${location}
- Currency: ${currency}
${notes ? `- Additional notes: ${notes}` : ""}`;

    const raw = await callGemini([{ text: userText }], {
      systemPrompt: SYSTEM_PROMPT,
      jsonMode: true,
      temperature: 0.3,
    });

    const parsed = parseJsonLoose<Record<string, unknown>>(raw);
    return jsonResponse({ result: parsed });
  } catch (e) {
    if (e instanceof Response) return e;
    console.error("ai-boq error:", e);
    return jsonResponse({ error: "Failed to generate the BOQ." }, 500);
  }
});
