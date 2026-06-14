-- Vendor material aggregation & index
-- NOTE: includes content from 017b_suppliers_table.sql which is skipped by CLI
-- due to non-numeric filename. All statements are idempotent (IF NOT EXISTS).

-- 0a) Suppliers table (from 017b — skipped by CLI naming rules)
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    category TEXT CHECK (category IN ('Cement', 'Steel', 'Sand', 'Aggregate', 'Bricks', 'Electrical', 'Plumbing', 'Hardware', 'Other')),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage suppliers" ON public.suppliers;
CREATE POLICY "Admins can manage suppliers"
ON public.suppliers FOR ALL TO authenticated
USING (public.is_admin_or_super()) WITH CHECK (public.is_admin_or_super());

DROP POLICY IF EXISTS "Site managers can view suppliers" ON public.suppliers;
CREATE POLICY "Site managers can view suppliers"
ON public.suppliers FOR SELECT TO authenticated
USING (public.get_my_role() = 'site_manager' AND is_active = true);

DROP POLICY IF EXISTS "Site managers can add suppliers" ON public.suppliers;
CREATE POLICY "Site managers can add suppliers"
ON public.suppliers FOR INSERT TO authenticated
WITH CHECK (public.get_my_role() = 'site_manager');

CREATE INDEX IF NOT EXISTS idx_suppliers_name ON public.suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_category ON public.suppliers(category);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON public.suppliers(is_active);

DROP TRIGGER IF EXISTS update_suppliers_updated_at ON public.suppliers;
CREATE TRIGGER update_suppliers_updated_at
    BEFORE UPDATE ON public.suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 0b) Ensure supplier_id column exists on material_logs
ALTER TABLE public.material_logs
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- 1) Index to speed supplier lookups
CREATE INDEX IF NOT EXISTS idx_material_logs_supplier
ON public.material_logs (supplier_id, project_id, log_type);

-- 2) Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin_or_super()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_or_super() TO authenticated;

-- 3) RPC: vendor material totals (per project, optionally per material)
CREATE OR REPLACE FUNCTION public.get_vendor_material_totals(
  p_vendor_id UUID,
  p_material_name TEXT DEFAULT NULL
)
RETURNS TABLE (
  project_id UUID,
  project_name TEXT,
  material_name TEXT,
  total_inward NUMERIC,
  total_outward NUMERIC,
  net NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH scoped_projects AS (
    SELECT id, name FROM public.projects
    WHERE deleted_at IS NULL
      AND (
        public.is_admin_or_super() OR
        id IN (SELECT project_id FROM public.project_assignments WHERE user_id = auth.uid())
      )
  ),
  base AS (
    SELECT 
      ml.project_id AS proj_id,
      sp.name AS proj_name,
      COALESCE(si.name, 'Unknown') AS mat_name,
      SUM(CASE WHEN ml.log_type = 'inward' THEN ml.quantity ELSE 0 END) AS total_inward,
      SUM(CASE WHEN ml.log_type = 'outward' THEN ml.quantity ELSE 0 END) AS total_outward
    FROM public.material_logs ml
    JOIN scoped_projects sp ON sp.id = ml.project_id
    LEFT JOIN public.stock_items si ON si.id = ml.item_id
    WHERE ml.supplier_id = p_vendor_id
      AND (p_material_name IS NULL OR lower(COALESCE(si.name, '')) = lower(p_material_name))
    GROUP BY ml.project_id, sp.name, COALESCE(si.name, 'Unknown')
  )
  SELECT 
    base.proj_id AS project_id,
    base.proj_name AS project_name,
    base.mat_name AS material_name,
    base.total_inward,
    base.total_outward,
    base.total_inward - base.total_outward AS net
  FROM base
  ORDER BY base.proj_name, base.mat_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_vendor_material_totals(UUID, TEXT) TO authenticated;

-- 4) RPC: vendor overview (admin-only, aggregates across all projects)
CREATE OR REPLACE FUNCTION public.get_vendor_overview()
RETURNS TABLE (
  vendor_id UUID,
  vendor_name TEXT,
  total_qty NUMERIC
) AS $$
BEGIN
  IF NOT public.is_admin_or_super() THEN
    RAISE EXCEPTION 'Only admins can access vendor overview';
  END IF;

  RETURN QUERY
  SELECT 
    v.id,
    v.name,
    COALESCE(SUM(ml.quantity), 0) AS total_qty
  FROM public.suppliers v
  LEFT JOIN public.material_logs ml ON ml.supplier_id = v.id AND ml.log_type = 'inward'
  GROUP BY v.id, v.name
  ORDER BY total_qty DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_vendor_overview() TO authenticated;
