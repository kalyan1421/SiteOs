-- ============================================================
-- 062_subcontractor.sql — Subcontractor Management (Phase 3)
-- ============================================================
-- Linear: AKS-85 (Subcontractor Management, Phase 3).
--
-- Adds the three tenant-scoped tables behind the SiteOS subcontractor module:
--   1. subcontractors — the firm/individual you award work to
--   2. work_orders    — a scope of work awarded to a subcontractor on a project
--   3. sub_ra_bills   — running-account bills raised against a work order,
--                       carrying TDS + retention deductions (mirrors the GST/RA
--                       billing math style used elsewhere in SiteOS)
--
-- Every table is multi-tenant: company_id UUID REFERENCES companies(id),
-- RLS enabled, and a policy filtering by company_id = public.current_company_id()
-- (helper from 052_saas_foundation.sql). Idempotent (IF NOT EXISTS / guarded
-- DO blocks). Depends on 052_saas_foundation.sql and the projects table.
-- ============================================================

-- 1. subcontractors ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subcontractors (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  gstin          TEXT,
  pan            TEXT,
  specialization TEXT,
  phone          TEXT,
  email          TEXT,
  address        TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subcontractors_company
  ON public.subcontractors (company_id);

-- 2. work_orders -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_orders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  subcontractor_id  UUID NOT NULL REFERENCES public.subcontractors(id) ON DELETE CASCADE,
  project_id        UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  wo_number         TEXT,
  scope             TEXT NOT NULL,
  value             NUMERIC(14,2) NOT NULL DEFAULT 0,
  retention_pct     NUMERIC(5,2) NOT NULL DEFAULT 0,
  tds_pct           NUMERIC(5,2) NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','on_hold','completed','cancelled')),
  start_date        DATE,
  end_date          DATE,
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_work_orders_company
  ON public.work_orders (company_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_subcontractor
  ON public.work_orders (subcontractor_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_project
  ON public.work_orders (project_id);

-- 3. sub_ra_bills ------------------------------------------------------------
-- net = value - tds - retention (computed on the client; stored for reporting).
CREATE TABLE IF NOT EXISTS public.sub_ra_bills (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  work_order_id  UUID NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
  number         TEXT NOT NULL,
  value          NUMERIC(14,2) NOT NULL DEFAULT 0,
  tds_pct        NUMERIC(5,2) NOT NULL DEFAULT 0,
  tds            NUMERIC(14,2) NOT NULL DEFAULT 0,
  retention_pct  NUMERIC(5,2) NOT NULL DEFAULT 0,
  retention      NUMERIC(14,2) NOT NULL DEFAULT 0,
  net            NUMERIC(14,2) NOT NULL DEFAULT 0,
  bill_date      DATE,
  status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','submitted','approved','paid')),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sub_ra_bills_company
  ON public.sub_ra_bills (company_id);
CREATE INDEX IF NOT EXISTS idx_sub_ra_bills_work_order
  ON public.sub_ra_bills (work_order_id);

-- 4. updated_at triggers (reuse the helper fn created in earlier migrations) --
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS trg_subcontractors_updated_at ON public.subcontractors;
    CREATE TRIGGER trg_subcontractors_updated_at
      BEFORE UPDATE ON public.subcontractors
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_work_orders_updated_at ON public.work_orders;
    CREATE TRIGGER trg_work_orders_updated_at
      BEFORE UPDATE ON public.work_orders
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_sub_ra_bills_updated_at ON public.sub_ra_bills;
    CREATE TRIGGER trg_sub_ra_bills_updated_at
      BEFORE UPDATE ON public.sub_ra_bills
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 5. Row Level Security ------------------------------------------------------
ALTER TABLE public.subcontractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_ra_bills   ENABLE ROW LEVEL SECURITY;

-- subcontractors: tenant members do everything within their own company.
DROP POLICY IF EXISTS "subcontractors tenant access" ON public.subcontractors;
CREATE POLICY "subcontractors tenant access" ON public.subcontractors
  FOR ALL
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- work_orders: same tenant isolation.
DROP POLICY IF EXISTS "work_orders tenant access" ON public.work_orders;
CREATE POLICY "work_orders tenant access" ON public.work_orders
  FOR ALL
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- sub_ra_bills: same tenant isolation.
DROP POLICY IF EXISTS "sub_ra_bills tenant access" ON public.sub_ra_bills;
CREATE POLICY "sub_ra_bills tenant access" ON public.sub_ra_bills
  FOR ALL
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());
