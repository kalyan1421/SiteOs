-- ============================================================
-- 060_purchase_orders.sql — SiteOS Phase 3: Purchase Order Workflow
-- ============================================================
-- Indent -> Purchase Order -> 3-way GRN match workflow.
--
-- Tables:
--   purchase_indents  — a material request raised against a project
--   indent_items      — line items of an indent (material, qty, unit)
--   purchase_orders   — PO raised from an indent against a supplier
--   po_items          — line items of a PO (material, qty, rate, amount)
--
-- Every table is tenant-scoped: company_id UUID REFERENCES companies(id),
-- RLS enabled, filtered by company_id = public.current_company_id()
-- (helper from 052_saas_foundation.sql).
--
-- Idempotent (IF NOT EXISTS / guarded DO blocks / DROP POLICY IF EXISTS).
-- Linear: AKS-83 (Purchase Order Workflow, Phase 3).
-- ============================================================

-- ── 1. purchase_indents ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_indents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_id   UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  indent_no    TEXT,
  title        TEXT,
  requested_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status       TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft','submitted','approved','rejected','closed')),
  notes        TEXT,
  required_by  DATE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_indents_company
  ON public.purchase_indents(company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_indents_project
  ON public.purchase_indents(project_id);

-- ── 2. indent_items ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.indent_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  indent_id  UUID NOT NULL REFERENCES public.purchase_indents(id) ON DELETE CASCADE,
  material   TEXT NOT NULL,
  qty        NUMERIC(15,3) NOT NULL DEFAULT 0,
  unit       TEXT,
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_indent_items_company
  ON public.indent_items(company_id);
CREATE INDEX IF NOT EXISTS idx_indent_items_indent
  ON public.indent_items(indent_id);

-- ── 3. purchase_orders ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  indent_id   UUID REFERENCES public.purchase_indents(id) ON DELETE SET NULL,
  project_id  UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  po_no       TEXT,
  status      TEXT NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','approved','received','cancelled')),
  total       NUMERIC(15,2) NOT NULL DEFAULT 0,
  notes       TEXT,
  expected_at DATE,
  created_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_company
  ON public.purchase_orders(company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_indent
  ON public.purchase_orders(indent_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier
  ON public.purchase_orders(supplier_id);

-- ── 4. po_items ─────────────────────────────────────────────────────
-- received_qty stored here so the 3-way match (PO ordered vs GRN received)
-- can be persisted and re-evaluated.
CREATE TABLE IF NOT EXISTS public.po_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  po_id        UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  material     TEXT NOT NULL,
  qty          NUMERIC(15,3) NOT NULL DEFAULT 0,
  unit         TEXT,
  rate         NUMERIC(15,2) NOT NULL DEFAULT 0,
  amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
  received_qty NUMERIC(15,3) NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_po_items_company
  ON public.po_items(company_id);
CREATE INDEX IF NOT EXISTS idx_po_items_po
  ON public.po_items(po_id);

-- ── 5. updated_at triggers (only if the shared helper fn exists) ─────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_purchase_indents_updated_at ON public.purchase_indents;
    CREATE TRIGGER trg_purchase_indents_updated_at
      BEFORE UPDATE ON public.purchase_indents
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_indent_items_updated_at ON public.indent_items;
    CREATE TRIGGER trg_indent_items_updated_at
      BEFORE UPDATE ON public.indent_items
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_purchase_orders_updated_at ON public.purchase_orders;
    CREATE TRIGGER trg_purchase_orders_updated_at
      BEFORE UPDATE ON public.purchase_orders
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_po_items_updated_at ON public.po_items;
    CREATE TRIGGER trg_po_items_updated_at
      BEFORE UPDATE ON public.po_items
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- ── 6. Row Level Security ───────────────────────────────────────────
ALTER TABLE public.purchase_indents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indent_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.po_items         ENABLE ROW LEVEL SECURITY;

-- purchase_indents: tenant-scoped full access.
DROP POLICY IF EXISTS "tenant manage purchase_indents" ON public.purchase_indents;
CREATE POLICY "tenant manage purchase_indents" ON public.purchase_indents
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- indent_items: tenant-scoped full access.
DROP POLICY IF EXISTS "tenant manage indent_items" ON public.indent_items;
CREATE POLICY "tenant manage indent_items" ON public.indent_items
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- purchase_orders: tenant-scoped full access.
DROP POLICY IF EXISTS "tenant manage purchase_orders" ON public.purchase_orders;
CREATE POLICY "tenant manage purchase_orders" ON public.purchase_orders
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- po_items: tenant-scoped full access.
DROP POLICY IF EXISTS "tenant manage po_items" ON public.po_items;
CREATE POLICY "tenant manage po_items" ON public.po_items
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- ============================================================
-- End 060_purchase_orders.sql
-- ============================================================
