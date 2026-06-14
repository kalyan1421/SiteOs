-- ============================================================
-- 061_rera.sql — SiteOS Phase 3: RERA Quarterly Reporting
-- ============================================================
-- Adds the `rera_reports` table that backs the RERA dashboard, quarterly
-- report form, and the RERA-format quarterly PDF export. Each row is a single
-- quarter's regulatory progress filing for one project.
--
-- Multi-tenant: every row carries company_id and is isolated via RLS using the
-- public.current_company_id() helper from 052_saas_foundation.sql.
-- Idempotent (IF NOT EXISTS / guarded DO blocks / ON CONFLICT).
-- Linear: AKS-84 (RERA Quarterly Reporting, Phase 3).
-- ============================================================

-- 1. rera_reports — one quarterly RERA filing per project -------------------
CREATE TABLE IF NOT EXISTS public.rera_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id       UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_id       UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  quarter          SMALLINT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
  year             SMALLINT NOT NULL CHECK (year BETWEEN 2015 AND 2100),
  completion_pct   NUMERIC(5,2) NOT NULL DEFAULT 0
                     CHECK (completion_pct >= 0 AND completion_pct <= 100),
  work_description TEXT,
  funds_received   NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (funds_received >= 0),
  funds_utilized   NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (funds_utilized >= 0),
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','submitted','approved')),
  created_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- one filing per project per quarter/year
  CONSTRAINT rera_reports_project_quarter_year_unique
    UNIQUE (project_id, quarter, year)
);

-- 2. Indexes ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_rera_reports_company
  ON public.rera_reports (company_id);
CREATE INDEX IF NOT EXISTS idx_rera_reports_project
  ON public.rera_reports (project_id);
CREATE INDEX IF NOT EXISTS idx_rera_reports_period
  ON public.rera_reports (year DESC, quarter DESC);

-- 3. updated_at trigger (only if the shared helper fn already exists) --------
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_rera_reports_updated_at ON public.rera_reports;
    CREATE TRIGGER trg_rera_reports_updated_at
      BEFORE UPDATE ON public.rera_reports
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 4. Row Level Security -----------------------------------------------------
ALTER TABLE public.rera_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rera_reports select own company" ON public.rera_reports;
CREATE POLICY "rera_reports select own company" ON public.rera_reports
  FOR SELECT TO authenticated
  USING (company_id = public.current_company_id());

DROP POLICY IF EXISTS "rera_reports insert own company" ON public.rera_reports;
CREATE POLICY "rera_reports insert own company" ON public.rera_reports
  FOR INSERT TO authenticated
  WITH CHECK (company_id = public.current_company_id());

DROP POLICY IF EXISTS "rera_reports update own company" ON public.rera_reports;
CREATE POLICY "rera_reports update own company" ON public.rera_reports
  FOR UPDATE TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

DROP POLICY IF EXISTS "rera_reports delete own company" ON public.rera_reports;
CREATE POLICY "rera_reports delete own company" ON public.rera_reports
  FOR DELETE TO authenticated
  USING (company_id = public.current_company_id());

-- ============================================================
-- End 061_rera.sql
-- ============================================================
