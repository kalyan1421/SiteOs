-- ============================================================
-- 059_gps_attendance.sql
-- Linear: AKS-82 — GPS / Geofencing Attendance (Phase 3)
-- ------------------------------------------------------------
-- Adds two tenant-scoped tables:
--   * project_geofences — one geofence (lat/lng + radius) per project.
--   * gps_checkins      — a labour/site-manager check-in with computed
--                         distance to the geofence and an in/out flag.
-- Both tables are company-scoped (company_id) with RLS filtering by
-- public.current_company_id() (helper from 052_saas_foundation.sql).
-- Idempotent — safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. project_geofences
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_geofences (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    project_id   UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    radius_m     INTEGER NOT NULL DEFAULT 200,
    label        TEXT,
    created_by   UUID REFERENCES public.user_profiles(id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One geofence per project.
CREATE UNIQUE INDEX IF NOT EXISTS project_geofences_project_id_key
    ON public.project_geofences (project_id);

CREATE INDEX IF NOT EXISTS project_geofences_company_id_idx
    ON public.project_geofences (company_id);

ALTER TABLE public.project_geofences ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'project_geofences'
      AND policyname = 'geofences_company_isolation'
  ) THEN
    CREATE POLICY "geofences_company_isolation"
      ON public.project_geofences
      FOR ALL
      TO authenticated
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;
END $$;

-- ------------------------------------------------------------
-- 2. gps_checkins
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gps_checkins (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id       UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    project_id       UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    labour_id        UUID REFERENCES public.labour(id) ON DELETE SET NULL,
    user_id          UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    lat              DOUBLE PRECISION NOT NULL,
    lng              DOUBLE PRECISION NOT NULL,
    distance_m       DOUBLE PRECISION NOT NULL DEFAULT 0,
    within_geofence  BOOLEAN NOT NULL DEFAULT false,
    checked_in_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS gps_checkins_company_id_idx
    ON public.gps_checkins (company_id);

CREATE INDEX IF NOT EXISTS gps_checkins_project_id_idx
    ON public.gps_checkins (project_id);

CREATE INDEX IF NOT EXISTS gps_checkins_checked_in_at_idx
    ON public.gps_checkins (checked_in_at DESC);

ALTER TABLE public.gps_checkins ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'gps_checkins'
      AND policyname = 'gps_checkins_company_isolation'
  ) THEN
    CREATE POLICY "gps_checkins_company_isolation"
      ON public.gps_checkins
      FOR ALL
      TO authenticated
      USING (company_id = public.current_company_id())
      WITH CHECK (company_id = public.current_company_id());
  END IF;
END $$;

-- ------------------------------------------------------------
-- 3. updated_at triggers (only if the shared helper fn exists)
-- ------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY['project_geofences', 'gps_checkins'];
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
