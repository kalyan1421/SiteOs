-- ============================================================
-- 064_subscriptions.sql — Razorpay recurring billing (Phase 0, AKS-66)
-- ============================================================
-- Adds the `subscriptions` ledger (one row per Razorpay subscription) and the
-- `subscription_invoices` ledger (one row per successful charge — powers the
-- billing-history screen). The `companies` table already carries `plan`,
-- `sub_id` and `sub_status` from 052_saas_foundation.sql; those remain the
-- source of truth the Flutter PlanGuard reads. These tables are the audit
-- trail behind them, written ONLY by the razorpay-webhook edge function
-- (service role). Users get read-only access to their own company's rows.
--
-- Idempotent (IF NOT EXISTS / guarded DO blocks). Safe to re-run.
-- Linear: AKS-66 (Razorpay subscriptions). Epic: AKS-64 (Phase 0 SaaS).
-- ============================================================

-- 1. subscriptions — one row per Razorpay subscription ----------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  rp_sub_id    TEXT UNIQUE,                       -- Razorpay subscription id (sub_xxx)
  plan_id      TEXT NOT NULL                      -- our plan key, not the Razorpay plan id
                 CHECK (plan_id IN ('starter','professional','enterprise')),
  status       TEXT NOT NULL DEFAULT 'created'
                 CHECK (status IN ('created','authenticated','active','pending',
                                   'halted','cancelled','completed','expired')),
  period_end   TIMESTAMPTZ,                       -- current_end of the latest cycle
  amount       NUMERIC(10,2),                     -- plan amount in rupees
  currency     TEXT NOT NULL DEFAULT 'INR',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_company_id
  ON public.subscriptions(company_id);

-- 2. subscription_invoices — one row per successful charge ------------------
CREATE TABLE IF NOT EXISTS public.subscription_invoices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  rp_payment_id   TEXT UNIQUE,                    -- Razorpay payment id (pay_xxx)
  rp_invoice_id   TEXT,                           -- Razorpay invoice id (inv_xxx)
  amount          NUMERIC(10,2) NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'INR',
  status          TEXT NOT NULL DEFAULT 'paid'
                    CHECK (status IN ('paid','failed','refunded')),
  paid_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sub_invoices_company_id
  ON public.subscription_invoices(company_id, paid_at DESC);

-- 3. updated_at trigger for subscriptions (only if the helper fn exists) ----
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_subscriptions_updated_at ON public.subscriptions;
    CREATE TRIGGER trg_subscriptions_updated_at
      BEFORE UPDATE ON public.subscriptions
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 4. Row Level Security ------------------------------------------------------
-- Read-only for company members. There is intentionally NO insert/update/delete
-- policy: only the razorpay-webhook edge function writes these tables, and it
-- uses the service-role key which bypasses RLS. Clients can never forge a
-- subscription or invoice.
ALTER TABLE public.subscriptions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_invoices  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read own subscriptions" ON public.subscriptions;
CREATE POLICY "members read own subscriptions" ON public.subscriptions
  FOR SELECT TO authenticated
  USING (company_id = public.current_company_id());

DROP POLICY IF EXISTS "members read own invoices" ON public.subscription_invoices;
CREATE POLICY "members read own invoices" ON public.subscription_invoices
  FOR SELECT TO authenticated
  USING (company_id = public.current_company_id());

-- ============================================================
-- Deploy notes (AKS-66):
--   supabase functions deploy razorpay-create-subscription
--   supabase functions deploy razorpay-webhook --no-verify-jwt
--   supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=... \
--     RAZORPAY_WEBHOOK_SECRET=... RAZORPAY_PLAN_STARTER=plan_xxx \
--     RAZORPAY_PLAN_PRO=plan_xxx
--   Razorpay dashboard → Webhooks → add <project>/functions/v1/razorpay-webhook
--     events: subscription.charged, subscription.activated, subscription.cancelled,
--             subscription.halted, subscription.completed
-- ============================================================
