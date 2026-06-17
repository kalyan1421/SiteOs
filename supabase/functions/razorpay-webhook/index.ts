// ============================================================================
// razorpay-webhook — apply Razorpay subscription events to plan state (AKS-66)
// ----------------------------------------------------------------------------
// Razorpay calls this server-to-server on subscription lifecycle events. It is
// the SOLE writer of `companies.plan` / `companies.sub_status` for paid plans,
// plus the `subscriptions` and `subscription_invoices` ledgers.
//
// Deploy WITHOUT JWT verification (Razorpay has no Supabase token):
//   supabase functions deploy razorpay-webhook --no-verify-jwt
// Security comes from the X-Razorpay-Signature HMAC, verified against the RAW
// body BEFORE parsing. An unsigned / mis-signed request is rejected 401.
//
// Events handled:
//   subscription.charged   → plan active, period_end advanced, invoice recorded
//   subscription.activated → plan active (first auth before first charge)
//   subscription.cancelled → downgrade to trial, sub_status canceled
//   subscription.halted    → sub_status past_due (retries exhausted)
//   subscription.completed → status completed (all cycles billed)
// Any other event is acknowledged (200) and ignored.
// ============================================================================

import {
  adminClient,
  jsonResponse,
  verifyWebhookSignature,
} from "../_shared/razorpay.ts";

type Db = ReturnType<typeof adminClient>;

interface SubEntity {
  id: string;
  status?: string;
  current_end?: number; // unix seconds
}

interface PaymentEntity {
  id: string;
  amount?: number; // paise
  currency?: string;
  invoice_id?: string;
}

/** Resolve the local subscription row (company_id + our plan key) by rp id. */
async function findSubscription(db: Db, rpSubId: string) {
  const { data } = await db
    .from("subscriptions")
    .select("id, company_id, plan_id")
    .eq("rp_sub_id", rpSubId)
    .maybeSingle();
  return data as
    | { id: string; company_id: string; plan_id: string }
    | null;
}

function isoFromUnix(seconds?: number): string | null {
  if (!seconds) return null;
  return new Date(seconds * 1000).toISOString();
}

async function handleCharged(db: Db, sub: SubEntity, payment: PaymentEntity) {
  const local = await findSubscription(db, sub.id);
  if (!local) {
    console.warn("charged: no local subscription for", sub.id);
    return; // ack — nothing we can attribute it to
  }

  const periodEnd = isoFromUnix(sub.current_end);

  await db.from("subscriptions").update({
    status: "active",
    period_end: periodEnd,
  }).eq("id", local.id);

  await db.from("companies").update({
    plan: local.plan_id,
    sub_status: "active",
    sub_id: sub.id,
  }).eq("id", local.company_id);

  // Invoice row for billing history. Idempotent on rp_payment_id (unique).
  if (payment?.id) {
    const { error } = await db.from("subscription_invoices").upsert({
      company_id: local.company_id,
      subscription_id: local.id,
      rp_payment_id: payment.id,
      rp_invoice_id: payment.invoice_id ?? null,
      amount: (payment.amount ?? 0) / 100, // paise → rupees
      currency: payment.currency ?? "INR",
      status: "paid",
    }, { onConflict: "rp_payment_id" });
    if (error) console.error("invoice upsert failed:", error.message);
  }
}

async function handleActivated(db: Db, sub: SubEntity) {
  const local = await findSubscription(db, sub.id);
  if (!local) return;
  await db.from("subscriptions").update({
    status: "active",
    period_end: isoFromUnix(sub.current_end),
  }).eq("id", local.id);
  await db.from("companies").update({
    plan: local.plan_id,
    sub_status: "active",
    sub_id: sub.id,
  }).eq("id", local.company_id);
}

async function handleCancelled(db: Db, sub: SubEntity) {
  const local = await findSubscription(db, sub.id);
  if (!local) return;
  await db.from("subscriptions").update({ status: "cancelled" })
    .eq("id", local.id);
  // Downgrade to trial tier with a canceled status — PlanGuard fails closed.
  await db.from("companies").update({
    plan: "trial",
    sub_status: "canceled",
  }).eq("id", local.company_id);
}

async function handleHalted(db: Db, sub: SubEntity) {
  const local = await findSubscription(db, sub.id);
  if (!local) return;
  await db.from("subscriptions").update({ status: "halted" })
    .eq("id", local.id);
  await db.from("companies").update({ sub_status: "past_due" })
    .eq("id", local.company_id);
}

async function handleCompleted(db: Db, sub: SubEntity) {
  const local = await findSubscription(db, sub.id);
  if (!local) return;
  await db.from("subscriptions").update({ status: "completed" })
    .eq("id", local.id);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // 1. Read the RAW body and verify the signature BEFORE parsing.
  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature");
  const valid = await verifyWebhookSignature(rawBody, signature);
  if (!valid) {
    console.warn("razorpay-webhook: invalid signature");
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch (_) {
    return jsonResponse({ error: "Malformed payload" }, 400);
  }

  const type = event["event"] as string | undefined;
  const payload = (event["payload"] ?? {}) as Record<string, unknown>;
  const sub = ((payload["subscription"] as Record<string, unknown>)?.["entity"] ??
    {}) as SubEntity;
  const payment =
    ((payload["payment"] as Record<string, unknown>)?.["entity"] ??
      {}) as PaymentEntity;

  if (!sub?.id) {
    // Not a subscription event we care about — acknowledge and move on.
    return jsonResponse({ received: true, ignored: type ?? "unknown" });
  }

  try {
    const db = adminClient();
    switch (type) {
      case "subscription.charged":
        await handleCharged(db, sub, payment);
        break;
      case "subscription.activated":
        await handleActivated(db, sub);
        break;
      case "subscription.cancelled":
        await handleCancelled(db, sub);
        break;
      case "subscription.halted":
        await handleHalted(db, sub);
        break;
      case "subscription.completed":
        await handleCompleted(db, sub);
        break;
      default:
        return jsonResponse({ received: true, ignored: type ?? "unknown" });
    }
    return jsonResponse({ received: true, handled: type });
  } catch (e) {
    // Return 500 so Razorpay retries — a transient DB error shouldn't drop the
    // event silently.
    console.error("razorpay-webhook handler error:", e);
    return jsonResponse({ error: "Handler failed" }, 500);
  }
});
