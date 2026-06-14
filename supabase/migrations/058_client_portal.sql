-- ============================================================
-- 058_client_portal.sql — SiteOS Phase 3: Client Portal
-- ============================================================
-- Adds a read-only "client" persona. A client user is a normal auth user whose
-- user_profiles.role = 'client'. They are granted SELECT-only visibility into a
-- curated subset of a company's data (assigned projects, their photos, and the
-- status of their RA / progress bills) via the new client_project_access table.
--
-- Design constraints honoured here:
--   * Cannot edit existing migrations, so the user_profiles.role CHECK is
--     widened in place: DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT (guarded).
--   * Every new table carries company_id and is protected by RLS filtering on
--     public.current_company_id() (helper from migration 052).
--   * Reference tables (projects, bills, blueprints) defensively — they may not
--     all have a company_id column on every deployment, so client visibility is
--     scoped through client_project_access (which DOES carry company_id) rather
--     than assuming a column exists on the referenced table.
--   * Idempotent: IF NOT EXISTS / guarded DO blocks / DROP POLICY IF EXISTS.
--
-- Linear: AKS-81 (Client Portal, Phase 3).
-- ============================================================

-- 1. Widen user_profiles.role to allow 'client' ------------------------------
-- The original CHECK (migration 001) is named user_profiles_role_check by
-- Postgres convention. We drop whatever role CHECK exists and re-add a widened
-- one. Done in a guarded DO block so a re-run (or a differently-named existing
-- constraint) never errors.
DO $$
DECLARE
  v_conname TEXT;
BEGIN
  -- Find any CHECK constraint on user_profiles whose definition mentions 'role'
  -- and the legacy role set, so we can drop it regardless of its exact name.
  SELECT c.conname INTO v_conname
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'user_profiles'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%role%'
    AND pg_get_constraintdef(c.oid) ILIKE '%site_manager%'
  LIMIT 1;

  IF v_conname IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS %I',
      v_conname
    );
  END IF;

  -- Also drop the conventionally-named one in case it differs from the above.
  ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;

  -- Add the widened constraint (idempotent: only if not already present).
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profiles_role_check'
      AND conrelid = 'public.user_profiles'::regclass
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_role_check
      CHECK (role IN ('super_admin', 'admin', 'site_manager', 'client'));
  END IF;
END $$;

-- 2. client_project_access — which projects a client user may read -----------
-- One row per (client_user_id, project_id). company_id is denormalised onto the
-- row so RLS can scope it without joining through projects (which may not carry
-- company_id on every deployment).
CREATE TABLE IF NOT EXISTS public.client_project_access (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  project_id     UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  company_id     UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (client_user_id, project_id)
);

CREATE INDEX IF NOT EXISTS idx_client_project_access_client
  ON public.client_project_access (client_user_id);
CREATE INDEX IF NOT EXISTS idx_client_project_access_project
  ON public.client_project_access (project_id);
CREATE INDEX IF NOT EXISTS idx_client_project_access_company
  ON public.client_project_access (company_id);

-- updated_at trigger (only if the shared helper exists, from earlier migrations)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_client_project_access_updated_at
      ON public.client_project_access;
    CREATE TRIGGER trg_client_project_access_updated_at
      BEFORE UPDATE ON public.client_project_access
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 3. Helper: is the caller a client user? ------------------------------------
-- SECURITY DEFINER so the role lookup bypasses user_profiles RLS and never
-- recurses through a policy.
CREATE OR REPLACE FUNCTION public.current_user_is_client()
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid() AND role = 'client'
  );
$$;

-- Helper: does the caller (a client) have access to this project? -------------
CREATE OR REPLACE FUNCTION public.client_can_access_project(p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.client_project_access cpa
    WHERE cpa.project_id = p_project_id
      AND cpa.client_user_id = auth.uid()
  );
$$;

-- 4. RLS on client_project_access -------------------------------------------
ALTER TABLE public.client_project_access ENABLE ROW LEVEL SECURITY;

-- Company members (admins/managers) manage access grants for their tenant.
DROP POLICY IF EXISTS "company members manage client access"
  ON public.client_project_access;
CREATE POLICY "company members manage client access"
  ON public.client_project_access
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- A client reads only their own access rows.
DROP POLICY IF EXISTS "client reads own access rows"
  ON public.client_project_access;
CREATE POLICY "client reads own access rows"
  ON public.client_project_access
  FOR SELECT TO authenticated
  USING (client_user_id = auth.uid());

-- 5. SELECT-only client visibility on referenced tables ----------------------
-- These are ADDITIVE policies (Postgres ORs multiple permissive policies), so
-- they never weaken existing admin/site_manager access — they only grant a
-- client SELECT on rows tied to a project they've been assigned.

-- 5a. projects: a client can SELECT assigned, non-deleted projects.
DROP POLICY IF EXISTS "client reads assigned projects" ON public.projects;
CREATE POLICY "client reads assigned projects"
  ON public.projects
  FOR SELECT TO authenticated
  USING (
    public.current_user_is_client()
    AND public.client_can_access_project(id)
    AND deleted_at IS NULL
  );

-- 5b. bills (RA / progress bill status): a client can SELECT bills for an
-- assigned project. This is the table RA bill status lives on in this schema.
DROP POLICY IF EXISTS "client reads assigned project bills" ON public.bills;
CREATE POLICY "client reads assigned project bills"
  ON public.bills
  FOR SELECT TO authenticated
  USING (
    public.current_user_is_client()
    AND public.client_can_access_project(project_id)
  );

-- 5c. blueprints / documents (used as the photo + document timeline source):
-- guarded because the table may not exist on every deployment.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'blueprints'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "client reads assigned project blueprints" ON public.blueprints';
    EXECUTE $pol$
      CREATE POLICY "client reads assigned project blueprints"
        ON public.blueprints
        FOR SELECT TO authenticated
        USING (
          public.current_user_is_client()
          AND public.client_can_access_project(project_id)
        )
    $pol$;
  END IF;
END $$;

-- 5d. project_photos (read-only progress photo timeline). Defensive: this table
-- may not exist on every deployment yet. If a future migration adds it with a
-- project_id column, this policy lets clients read photos for assigned projects.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'project_photos'
      AND column_name = 'project_id'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "client reads assigned project photos" ON public.project_photos';
    EXECUTE $pol$
      CREATE POLICY "client reads assigned project photos"
        ON public.project_photos
        FOR SELECT TO authenticated
        USING (
          public.current_user_is_client()
          AND public.client_can_access_project(project_id)
        )
    $pol$;
  END IF;
END $$;

-- ============================================================
-- NOTES for the Flutter/backend integration:
--   * RA bill status is read from public.bills (no dedicated ra_bills table in
--     this schema). The client billing screen treats bill_type in
--     ('invoice','income') as the RA/progress bill family and shows status.
--   * Progress photos: the timeline reads from public.project_photos if present,
--     otherwise it gracefully shows an empty state. blueprints SELECT is also
--     granted so image/PDF documents are visible to clients.
--   * To onboard a client: create their auth user + user_profiles row with
--     role='client' and the same company_id, then INSERT client_project_access
--     rows for each project they may see (done by an admin under existing RLS).
-- ============================================================
