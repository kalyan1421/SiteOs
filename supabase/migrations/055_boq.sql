-- ============================================================
-- 055_boq.sql — SiteOS BOQ / Estimation Module (Phase 1)
-- ============================================================
-- Bill of Quantities headers + line items, scoped per project and per tenant.
-- A BOQ header is a named, versioned estimate for one project. Line items are
-- grouped by category (e.g. Earthwork, Concrete, Steel) and carry qty × rate.
-- The line `amount` is a GENERATED column so it can never drift from qty/rate.
--
-- Multi-tenant: every row carries company_id and is protected by RLS that
-- filters on public.current_company_id() (helper from 052_saas_foundation.sql).
-- Idempotent (IF NOT EXISTS / guarded DO blocks). Safe to re-run.
-- Linear: AKS-72 (BOQ / Estimation Module — Phase 1).
-- ============================================================

-- 1. boq_headers — one named, versioned estimate per project -----------------
CREATE TABLE IF NOT EXISTS public.boq_headers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_id  UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  version     TEXT NOT NULL DEFAULT 'v1',
  notes       TEXT,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_boq_headers_project
  ON public.boq_headers (project_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_boq_headers_company
  ON public.boq_headers (company_id);

-- 2. boq_items — line items grouped by category ------------------------------
-- amount = qty * rate, computed by Postgres (GENERATED ALWAYS … STORED).
CREATE TABLE IF NOT EXISTS public.boq_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  boq_id       UUID NOT NULL REFERENCES public.boq_headers(id) ON DELETE CASCADE,
  category     TEXT NOT NULL DEFAULT 'General',
  description  TEXT NOT NULL,
  unit         TEXT NOT NULL DEFAULT 'nos',
  qty          NUMERIC(15, 3) NOT NULL DEFAULT 0 CHECK (qty >= 0),
  rate         NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (rate >= 0),
  amount       NUMERIC(18, 2) GENERATED ALWAYS AS (qty * rate) STORED,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_boq_items_boq
  ON public.boq_items (boq_id, category, sort_order);

CREATE INDEX IF NOT EXISTS idx_boq_items_company
  ON public.boq_items (company_id);

-- 3. updated_at triggers (reuse set_updated_at helper if present) -------------
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_boq_headers_updated_at ON public.boq_headers;
    CREATE TRIGGER trg_boq_headers_updated_at
      BEFORE UPDATE ON public.boq_headers
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_boq_items_updated_at ON public.boq_items;
    CREATE TRIGGER trg_boq_items_updated_at
      BEFORE UPDATE ON public.boq_items
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 4. Row Level Security ------------------------------------------------------
ALTER TABLE public.boq_headers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boq_items   ENABLE ROW LEVEL SECURITY;

-- boq_headers: full access to rows belonging to the caller's company.
DROP POLICY IF EXISTS "boq_headers tenant access" ON public.boq_headers;
CREATE POLICY "boq_headers tenant access" ON public.boq_headers
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- boq_items: full access to rows belonging to the caller's company.
DROP POLICY IF EXISTS "boq_items tenant access" ON public.boq_items;
CREATE POLICY "boq_items tenant access" ON public.boq_items
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- ============================================================
-- BOQ vs ACTUAL (read-only) -------------------------------------------------
-- "Actual" consumption is read from existing material tables:
--   material_logs (log_type = 'outward')  ->  qty consumed
--   stock_items.category                  ->  the category bucket
-- The app aggregates these client-side per BOQ/project for the comparison
-- screen; no extra table is required here. See boq_repository.dart.
-- ============================================================
