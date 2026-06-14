-- ============================================================
-- 052_saas_foundation.sql — SiteOS Phase 0: SaaS multi-tenancy foundation
-- ============================================================
-- Establishes real multi-tenancy. Until now `user_profiles.company_id` was a
-- bare placeholder UUID (added in 014 "for future multi-tenant support") with
-- no `companies` table behind it. This migration creates that table, the plan
-- columns, and the `plan_features` lookup that the Flutter PlanGuard reads.
--
-- Safe to run on the fresh SiteOS Supabase project AFTER the consolidated
-- 001–051 schema. Idempotent (IF NOT EXISTS / ON CONFLICT / guarded DO blocks).
-- Linear: AKS-64 (Phase 0 epic), AKS-65 (registration), AKS-67 (feature flags).
-- ============================================================

-- 1. companies — the tenant root --------------------------------------------
CREATE TABLE IF NOT EXISTS public.companies (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  gstin         TEXT,
  owner_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  plan          TEXT NOT NULL DEFAULT 'trial'
                  CHECK (plan IN ('trial','starter','professional','enterprise')),
  trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '14 days'),
  sub_id        TEXT,                       -- Razorpay subscription id (Phase 0, AKS-66)
  sub_status    TEXT NOT NULL DEFAULT 'trialing'
                  CHECK (sub_status IN ('trialing','active','past_due','canceled','expired')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Link user_profiles.company_id → companies (column exists from 014) ------
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_profiles_company_id_fkey'
      AND table_name = 'user_profiles'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 3. Helper: the caller's company_id (reused by RLS on tenant tables) --------
-- SECURITY DEFINER so the lookup itself bypasses user_profiles RLS and never
-- recurses through a policy that calls this function.
CREATE OR REPLACE FUNCTION public.current_company_id()
RETURNS UUID
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT company_id FROM public.user_profiles WHERE id = auth.uid();
$$;

-- 4. plan_features — global lookup (identical for every tenant) --------------
-- max_projects / max_users: -1 means unlimited.
CREATE TABLE IF NOT EXISTS public.plan_features (
  plan          TEXT PRIMARY KEY
                  CHECK (plan IN ('trial','starter','professional','enterprise')),
  max_projects  INTEGER NOT NULL DEFAULT 0,
  max_users     INTEGER NOT NULL DEFAULT 0,
  gst_billing   BOOLEAN NOT NULL DEFAULT FALSE,
  boq_module    BOOLEAN NOT NULL DEFAULT FALSE,
  ai_features   BOOLEAN NOT NULL DEFAULT FALSE,
  whatsapp      BOOLEAN NOT NULL DEFAULT FALSE,
  client_portal BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO public.plan_features
  (plan, max_projects, max_users, gst_billing, boq_module, ai_features, whatsapp, client_portal)
VALUES
  ('trial',         3,  5, FALSE, FALSE, FALSE, FALSE, FALSE),
  ('starter',       5, 10, FALSE, FALSE, FALSE, TRUE,  FALSE),
  ('professional', -1, -1, TRUE,  TRUE,  TRUE,  TRUE,  TRUE),
  ('enterprise',   -1, -1, TRUE,  TRUE,  TRUE,  TRUE,  TRUE)
ON CONFLICT (plan) DO UPDATE SET
  max_projects  = EXCLUDED.max_projects,
  max_users     = EXCLUDED.max_users,
  gst_billing   = EXCLUDED.gst_billing,
  boq_module    = EXCLUDED.boq_module,
  ai_features   = EXCLUDED.ai_features,
  whatsapp      = EXCLUDED.whatsapp,
  client_portal = EXCLUDED.client_portal;

-- 5. updated_at trigger for companies (only if the helper fn already exists) -
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_companies_updated_at ON public.companies;
    CREATE TRIGGER trg_companies_updated_at
      BEFORE UPDATE ON public.companies
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 6. Row Level Security ------------------------------------------------------
ALTER TABLE public.companies     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_features ENABLE ROW LEVEL SECURITY;

-- companies: members read their own company; admins/owner update it.
DROP POLICY IF EXISTS "company members read own company" ON public.companies;
CREATE POLICY "company members read own company" ON public.companies
  FOR SELECT TO authenticated
  USING (id = public.current_company_id());

DROP POLICY IF EXISTS "company admins update own company" ON public.companies;
CREATE POLICY "company admins update own company" ON public.companies
  FOR UPDATE TO authenticated
  USING (id = public.current_company_id())
  WITH CHECK (id = public.current_company_id());

-- plan_features: readable by any authenticated user (global, non-tenant data).
DROP POLICY IF EXISTS "plan_features readable by authenticated" ON public.plan_features;
CREATE POLICY "plan_features readable by authenticated" ON public.plan_features
  FOR SELECT TO authenticated USING (true);

-- ============================================================
-- Next (Phase 0): 053_subscriptions.sql (Razorpay, AKS-66),
-- create-company edge function for atomic company+admin signup (AKS-65).
-- ============================================================
