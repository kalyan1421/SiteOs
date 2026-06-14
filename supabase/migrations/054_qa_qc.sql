-- =============================================================================
-- 054_qa_qc.sql — QA/QC Snag Lists (Phase 1)
-- Linear issue: AKS-70
--
-- Adds the QA/QC module: reusable checklist templates, per-project checklist
-- instances with pass/fail/na items, and a snag (defect) register with
-- before/after photos stored in the 'snags' Storage bucket.
--
-- Multi-tenancy: every table carries company_id REFERENCES companies(id),
-- RLS is enabled, and the access policy filters by
-- company_id = public.current_company_id() (helper from 052_saas_foundation.sql).
-- Idempotent: safe to re-run.
-- =============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- 1. checklist_templates — reusable named templates (admin-managed)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  description  TEXT,
  category     TEXT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_by   UUID REFERENCES public.user_profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_checklist_templates_company
  ON public.checklist_templates (company_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 2. checklist_template_items — ordered line items belonging to a template
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.checklist_template_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  template_id   UUID NOT NULL REFERENCES public.checklist_templates(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template
  ON public.checklist_template_items (template_id);
CREATE INDEX IF NOT EXISTS idx_checklist_template_items_company
  ON public.checklist_template_items (company_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 3. project_checklists — a checklist instance applied to a project
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.project_checklists (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_id    UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  template_id   UUID REFERENCES public.checklist_templates(id) ON DELETE SET NULL,
  name          TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'in_progress', 'completed')),
  created_by    UUID REFERENCES public.user_profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_project_checklists_project
  ON public.project_checklists (project_id);
CREATE INDEX IF NOT EXISTS idx_project_checklists_company
  ON public.project_checklists (company_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 4. checklist_items — pass/fail/na line items of a project checklist
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.checklist_items (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_checklist_id  UUID NOT NULL REFERENCES public.project_checklists(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  description           TEXT,
  status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'pass', 'fail', 'na')),
  notes                 TEXT,
  sort_order            INTEGER NOT NULL DEFAULT 0,
  checked_by            UUID REFERENCES public.user_profiles(id),
  checked_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_checklist_items_checklist
  ON public.checklist_items (project_checklist_id);
CREATE INDEX IF NOT EXISTS idx_checklist_items_company
  ON public.checklist_items (company_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 5. snags — defect register, linked to a project and optional checklist item
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.snags (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id         UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  project_id         UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  checklist_item_id  UUID REFERENCES public.checklist_items(id) ON DELETE SET NULL,
  title              TEXT NOT NULL,
  description        TEXT,
  location           TEXT,
  priority           TEXT NOT NULL DEFAULT 'medium'
                       CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  status             TEXT NOT NULL DEFAULT 'open'
                       CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  raised_by          UUID REFERENCES public.user_profiles(id),
  assigned_to        UUID REFERENCES public.user_profiles(id),
  resolved_by        UUID REFERENCES public.user_profiles(id),
  resolved_at        TIMESTAMPTZ,
  resolution_notes   TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_snags_project ON public.snags (project_id);
CREATE INDEX IF NOT EXISTS idx_snags_company ON public.snags (company_id);
CREATE INDEX IF NOT EXISTS idx_snags_checklist_item
  ON public.snags (checklist_item_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 6. snag_photos — before/after photo URLs for a snag (stored in 'snags' bucket)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.snag_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  snag_id      UUID NOT NULL REFERENCES public.snags(id) ON DELETE CASCADE,
  photo_url    TEXT NOT NULL,
  storage_path TEXT,
  kind         TEXT NOT NULL DEFAULT 'before'
                 CHECK (kind IN ('before', 'after')),
  uploaded_by  UUID REFERENCES public.user_profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_snag_photos_snag ON public.snag_photos (snag_id);
CREATE INDEX IF NOT EXISTS idx_snag_photos_company
  ON public.snag_photos (company_id);

-- ──────────────────────────────────────────────────────────────────────────
-- 7. updated_at triggers (only if the shared helper fn exists)
-- ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'checklist_templates',
    'checklist_template_items',
    'project_checklists',
    'checklist_items',
    'snags',
    'snag_photos'
  ];
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    FOREACH t IN ARRAY tables LOOP
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON public.%s;', t, t);
      EXECUTE format(
        'CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON public.%s '
        'FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();', t, t);
    END LOOP;
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- 8. Row Level Security — tenant isolation by company_id
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.checklist_templates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_template_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_checklists        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snags                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snag_photos               ENABLE ROW LEVEL SECURITY;

-- One "all access within own company" policy per table.
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'checklist_templates',
    'checklist_template_items',
    'project_checklists',
    'checklist_items',
    'snags',
    'snag_photos'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%s tenant access" ON public.%s;', t, t);
    EXECUTE format(
      'CREATE POLICY "%s tenant access" ON public.%s '
      'FOR ALL TO authenticated '
      'USING (company_id = public.current_company_id()) '
      'WITH CHECK (company_id = public.current_company_id());', t, t);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- 9. Storage bucket 'snags' for before/after photos + tenant-scoped policies
--    Convention: object paths are '<project_id>/<snag_id>/<file>' and the
--    bucket is private; the app reads via signed/public URLs as configured.
-- ──────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('snags', 'snags', TRUE)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "snags bucket read" ON storage.objects;
CREATE POLICY "snags bucket read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'snags');

DROP POLICY IF EXISTS "snags bucket insert" ON storage.objects;
CREATE POLICY "snags bucket insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'snags');

DROP POLICY IF EXISTS "snags bucket update" ON storage.objects;
CREATE POLICY "snags bucket update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'snags');

DROP POLICY IF EXISTS "snags bucket delete" ON storage.objects;
CREATE POLICY "snags bucket delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'snags');
