// ============================================================================
// ai-invoice-ocr — Gemini Vision invoice/bill parser (Linear AKS-75)
// ----------------------------------------------------------------------------
// Input  : { image_base64: string, mime_type?: string }
//          image_base64 is the raw base64 of a vendor invoice photo/scan.
// Output : { vendor, gstin, invoice_no, invoice_date, line_items[], total,
//            tax_amount, currency }
//
// Flow: Flutter picks an image (file_picker) -> base64 -> invoke this fn ->
//       Gemini 1.5 Flash Vision extracts structured fields -> JSON back.
//
// GEMINI_API_KEY is read from the Edge Function env (see _shared/gemini.ts).
// It is never exposed to the Flutter client.
// ============================================================================

import {
  callGemini,
  handlePreflight,
  jsonResponse,
  parseJsonLoose,
  requireCaller,
} from "../_shared/gemini.ts";

const SYSTEM_PROMPT = `You are an expert at reading Indian construction-supplier
invoices and GST bills (English and Hindi). Extract the fields below from the
attached invoice image. Use the data ONLY from the image — never invent values.
If a field is not present, use null (or [] for line_items).

Return STRICT JSON with exactly this shape:
{
  "vendor": string|null,            // supplier / company name
  "gstin": string|null,             // 15-char GSTIN if printed
  "invoice_no": string|null,
  "invoice_date": string|null,      // ISO yyyy-mm-dd if you can parse it
  "line_items": [
    { "description": string, "quantity": number|null, "unit": string|null,
      "rate": number|null, "amount": number|null }
  ],
  "tax_amount": number|null,        // total GST amount
  "total": number|null,             // grand total payable
  "currency": string                // "INR" unless clearly otherwise
}
All numbers must be plain numbers (no currency symbols, no commas).`;

Deno.serve(async (req: Request) => {
  const pre = handlePreflight(req);
  if (pre) return pre;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    // Auth: must be a signed-in user (company gating is enforced in-app by
    // PlanGuard; here we just reject anonymous calls).
    await requireCaller(req);

    const body = await req.json().catch(() => ({}));
    const imageBase64: string | undefined = body.image_base64;
    const mimeType: string = body.mime_type ?? "image/jpeg";

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return jsonResponse({ error: "image_base64 is required" }, 400);
    }

    const raw = await callGemini(
      [
        { text: "Extract the invoice fields from this image." },
        { inlineData: { mimeType, data: imageBase64 } },
      ],
      { systemPrompt: SYSTEM_PROMPT, jsonMode: true, temperature: 0.1 },
    );

    const parsed = parseJsonLoose<Record<string, unknown>>(raw);
    return jsonResponse({ result: parsed });
  } catch (e) {
    // Helpers throw Response objects for known error paths.
    if (e instanceof Response) return e;
    console.error("ai-invoice-ocr error:", e);
    return jsonResponse({ error: "Failed to read the invoice." }, 500);
  }
});
