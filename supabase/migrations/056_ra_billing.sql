-- ============================================================
-- 056_ra_billing.sql — SiteOS: GST / RA Billing + Tally Export (Phase 1)
-- ============================================================
-- Adds the GST / Running-Account (RA) billing module: per-company GST config,
-- clients, project contracts, and RA bills with full GST/retention/advance/TDS
-- breakdown. Every tenant table carries company_id, has RLS enabled, and is
-- filtered by public.current_company_id() (helper from 052_saas_foundation.sql).
--
-- Safe to run AFTER 052_saas_foundation.sql. Idempotent
-- (IF NOT EXISTS / guarded DO blocks).
-- Linear: AKS-73 (GST / RA Billing + Tally Export, Phase 1).
-- ============================================================

-- 1. company_gst_config — one GST/bank profile per tenant -------------------
CREATE TABLE IF NOT EXISTS public.company_gst_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    legal_name TEXT,
    gstin TEXT,
    state_code TEXT,
    pan TEXT,
    address TEXT,
    bank_name TEXT,
    bank_account_no TEXT,
    bank_ifsc TEXT,
    bank_branch TEXT,
    default_tds_pct NUMERIC(6, 3) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One config row per company.
CREATE UNIQUE INDEX IF NOT EXISTS company_gst_config_company_id_key
    ON public.company_gst_config (company_id);

-- 2. clients — billable parties (employers / customers) ---------------------
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    gstin TEXT,
    state_code TEXT,
    address TEXT,
    contact_person TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS clients_company_id_idx
    ON public.clients (company_id);

-- 3. project_contracts — a contract between the company and a client ---------
CREATE TABLE IF NOT EXISTS public.project_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    contract_value NUMERIC(16, 2) NOT NULL DEFAULT 0,
    retention_pct NUMERIC(6, 3) NOT NULL DEFAULT 0,
    advance NUMERIC(16, 2) NOT NULL DEFAULT 0,
    advance_recovery_pct NUMERIC(6, 3) NOT NULL DEFAULT 0,
    gst_rate NUMERIC(6, 3) NOT NULL DEFAULT 18,
    tds_pct NUMERIC(6, 3) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS project_contracts_company_id_idx
    ON public.project_contracts (company_id);
CREATE INDEX IF NOT EXISTS project_contracts_client_id_idx
    ON public.project_contracts (client_id);

-- 4. ra_bills — running-account bills with full GST breakdown ----------------
CREATE TABLE IF NOT EXISTS public.ra_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    contract_id UUID NOT NULL REFERENCES public.project_contracts(id) ON DELETE CASCADE,
    number TEXT NOT NULL,
    bill_date DATE NOT NULL DEFAULT CURRENT_DATE,
    cumulative_work_done NUMERIC(16, 2) NOT NULL DEFAULT 0,
    previous_work_done NUMERIC(16, 2) NOT NULL DEFAULT 0,
    this_bill_value NUMERIC(16, 2) NOT NULL DEFAULT 0,
    advance_recovery NUMERIC(16, 2) NOT NULL DEFAULT 0,
    retention NUMERIC(16, 2) NOT NULL DEFAULT 0,
    taxable_value NUMERIC(16, 2) NOT NULL DEFAULT 0,
    cgst NUMERIC(16, 2) NOT NULL DEFAULT 0,
    sgst NUMERIC(16, 2) NOT NULL DEFAULT 0,
    igst NUMERIC(16, 2) NOT NULL DEFAULT 0,
    tds NUMERIC(16, 2) NOT NULL DEFAULT 0,
    net_payable NUMERIC(16, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'paid')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ra_bills_company_id_idx
    ON public.ra_bills (company_id);
CREATE INDEX IF NOT EXISTS ra_bills_contract_id_idx
    ON public.ra_bills (contract_id);

-- 5. Row-Level Security ------------------------------------------------------
ALTER TABLE public.company_gst_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_contracts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ra_bills           ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'company_gst_config'
      AND policyname = 'company_gst_config_tenant'
  ) THEN
    CREATE POLICY company_gst_config_tenant ON public.company_gst_config
      FOR ALL
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'clients'
      AND policyname = 'clients_tenant'
  ) THEN
    CREATE POLICY clients_tenant ON public.clients
      FOR ALL
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'project_contracts'
      AND policyname = 'project_contracts_tenant'
  ) THEN
    CREATE POLICY project_contracts_tenant ON public.project_contracts
      FOR ALL
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'ra_bills'
      AND policyname = 'ra_bills_tenant'
  ) THEN
    CREATE POLICY ra_bills_tenant ON public.ra_bills
      FOR ALL
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;
END $$;

-- ============================================================
-- End 056_ra_billing.sql
-- ============================================================
