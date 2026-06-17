// ============================================================================
// razorpay-create-subscription — start a recurring INR subscription (AKS-66)
// ----------------------------------------------------------------------------
// Input  : { plan: "starter" | "professional" }
// Output : { rp_sub_id, key_id, amount, currency, plan }
//
// Flow: the Flutter plans screen calls this. We create the subscription on
//       Razorpay SERVER-SIDE (the key secret never reaches the app), record a
//       `subscriptions` row (status 'created'), and return the subscription id
//       + publishable key id so the app can open the Razorpay checkout. The
//       plan only flips to active once Razorpay fires `subscription.charged`,
//       which the razorpay-webhook function verifies and applies.
//
// Security: requires a signed-in caller with a company. Only admins/owners
// should reach the upgrade UI; the webhook is the sole writer of plan state.
// ============================================================================

import {
  adminClient,
  createRazorpaySubscription,
  handlePreflight,
  jsonResponse,
  PLAN_AMOUNT,
  type PlanKey,
  razorpayConfigured,
  razorpayKeyId,
  requireCaller,
} from "../_shared/razorpay.ts";

Deno.serve(async (req: Request) => {
  const pre = handlePreflight(req);
  if (pre) return pre;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    if (!razorpayConfigured()) {
      return jsonResponse(
        { error: "Billing is not configured. Please contact support." },
        500,
      );
    }

    const caller = await requireCaller(req);
    if (!caller.companyId) {
      return jsonResponse({ error: "No company linked to this account." }, 400);
    }

    const body = await req.json().catch(() => ({}));
    const plan = body.plan as string;
    if (plan !== "starter" && plan !== "professional") {
      return jsonResponse(
        { error: "plan must be 'starter' or 'professional'." },
        400,
      );
    }
    const planKey = plan as PlanKey;

    // Create the subscription on Razorpay (server-side, secret stays here).
    const sub = await createRazorpaySubscription(planKey, {
      notes: { company_id: caller.companyId, user_id: caller.userId },
    });

    // Record the intent. The webhook will move this to 'active' on first charge.
    // Service role: this table has no client-write RLS policy by design.
    const db = adminClient();
    const { error: insErr } = await db.from("subscriptions").insert({
      company_id: caller.companyId,
      rp_sub_id: sub.rpSubId,
      plan_id: planKey,
      status: sub.status,
      amount: PLAN_AMOUNT[planKey],
      currency: "INR",
    });
    if (insErr) {
      console.error("Failed to record subscription:", insErr.message);
      // Non-fatal for the user — the webhook upserts on company_id+rp_sub_id
      // anyway — but log it so we notice drift.
    }

    return jsonResponse({
      rp_sub_id: sub.rpSubId,
      key_id: razorpayKeyId(),
      amount: PLAN_AMOUNT[planKey],
      currency: "INR",
      plan: planKey,
    });
  } catch (e) {
    if (e instanceof Response) return e;
    console.error("razorpay-create-subscription error:", e);
    return jsonResponse({ error: "Failed to start subscription." }, 500);
  }
});
