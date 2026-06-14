-- ============================================================
-- 057_whatsapp.sql — SiteOS WhatsApp Integration (Phase 1)
-- ============================================================
-- Adds per-company WhatsApp configuration, daily-report preferences, and an
-- outbound message log. Phase 1 sends transactional templates (e.g. the daily
-- progress report) via the Meta WhatsApp Cloud API through the
-- `whatsapp-send` edge function.
--
-- SECURITY: the Meta access token is NEVER stored in the database. The token
-- and phone-number id live only as edge-function secrets
-- (WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID). `whatsapp_config` only
-- records a `configured` boolean + non-secret display fields so the app can
-- show connection status.
--
-- Depends on 052_saas_foundation.sql (companies, current_company_id(),
-- set_updated_at). Idempotent (IF NOT EXISTS / guarded DO blocks).
-- Linear: AKS-71 (WhatsApp Integration — Phase 1).
-- ============================================================

-- 1. whatsapp_config — one row per company (connection status, display only) --
CREATE TABLE IF NOT EXISTS public.whatsapp_config (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  configured        BOOLEAN NOT NULL DEFAULT FALSE,
  -- Non-secret display fields ONLY. The real access_token + phone_number_id
  -- are edge-function secrets and must NOT be written here.
  phone_number_id   TEXT,            -- display-only echo of the configured id (optional)
  display_phone     TEXT,            -- e.g. "+91 98765 43210" shown in the UI
  business_name     TEXT,            -- WhatsApp Business display name (optional)
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT whatsapp_config_company_unique UNIQUE (company_id)
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_config_company
  ON public.whatsapp_config (company_id);

-- 2. whatsapp_preferences — daily report opt-in + recipients ------------------
CREATE TABLE IF NOT EXISTS public.whatsapp_preferences (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id           UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  daily_report_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  -- JSON array of recipient objects: [{"name":"Site Owner","phone":"+919876543210"}]
  recipients           JSONB NOT NULL DEFAULT '[]'::jsonb,
  send_hour            INTEGER NOT NULL DEFAULT 19
                         CHECK (send_hour >= 0 AND send_hour <= 23),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT whatsapp_preferences_company_unique UNIQUE (company_id)
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_preferences_company
  ON public.whatsapp_preferences (company_id);

-- 3. whatsapp_logs — outbound message audit log ------------------------------
CREATE TABLE IF NOT EXISTS public.whatsapp_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  template     TEXT NOT NULL,                       -- Meta template name
  "to"         TEXT NOT NULL,                       -- E.164 recipient phone
  status       TEXT NOT NULL DEFAULT 'queued'
                 CHECK (status IN ('queued','sent','failed')),
  payload      JSONB,                               -- request params + Meta response/error
  sent_at      TIMESTAMPTZ,                         -- set when Meta accepts the message
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_company_created
  ON public.whatsapp_logs (company_id, created_at DESC);

-- 4. updated_at triggers (only if the shared helper fn exists) ----------------
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_whatsapp_config_updated_at ON public.whatsapp_config;
    CREATE TRIGGER trg_whatsapp_config_updated_at
      BEFORE UPDATE ON public.whatsapp_config
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_whatsapp_preferences_updated_at ON public.whatsapp_preferences;
    CREATE TRIGGER trg_whatsapp_preferences_updated_at
      BEFORE UPDATE ON public.whatsapp_preferences
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    DROP TRIGGER IF EXISTS trg_whatsapp_logs_updated_at ON public.whatsapp_logs;
    CREATE TRIGGER trg_whatsapp_logs_updated_at
      BEFORE UPDATE ON public.whatsapp_logs
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 5. Row Level Security ------------------------------------------------------
ALTER TABLE public.whatsapp_config      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_logs        ENABLE ROW LEVEL SECURITY;

-- whatsapp_config: members of the company can read/write their own config row.
DROP POLICY IF EXISTS "whatsapp_config tenant access" ON public.whatsapp_config;
CREATE POLICY "whatsapp_config tenant access" ON public.whatsapp_config
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- whatsapp_preferences: same tenant scoping.
DROP POLICY IF EXISTS "whatsapp_preferences tenant access" ON public.whatsapp_preferences;
CREATE POLICY "whatsapp_preferences tenant access" ON public.whatsapp_preferences
  FOR ALL TO authenticated
  USING (company_id = public.current_company_id())
  WITH CHECK (company_id = public.current_company_id());

-- whatsapp_logs: members read their own company's logs. Inserts/updates are
-- written by the edge function using the service_role key (bypasses RLS), so
-- only a SELECT policy is exposed to authenticated app users.
DROP POLICY IF EXISTS "whatsapp_logs tenant read" ON public.whatsapp_logs;
CREATE POLICY "whatsapp_logs tenant read" ON public.whatsapp_logs
  FOR SELECT TO authenticated
  USING (company_id = public.current_company_id());

-- ============================================================
-- 6. Scheduled daily reports (pg_cron) — SETUP REFERENCE (commented).
-- ============================================================
-- The daily progress report should fire at 19:00 IST. Postgres cron runs in
-- UTC, so 19:00 IST == 13:30 UTC. Enable pg_cron + pg_net once per project,
-- then schedule a job that calls the `whatsapp-send` edge function (which in
-- turn fans out to each enabled company's recipients).
--
-- Run the block below MANUALLY in the Supabase SQL editor (it is left
-- commented here because pg_cron/pg_net + the project ref + service-role key
-- are environment-specific and must not live in a committed migration):
--
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
--   CREATE EXTENSION IF NOT EXISTS pg_net;
--
--   -- 13:30 UTC == 19:00 IST, every day.
--   SELECT cron.schedule(
--     'whatsapp-daily-report',
--     '30 13 * * *',
--     $cron$
--       SELECT net.http_post(
--         url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/whatsapp-send',
--         headers := jsonb_build_object(
--           'Content-Type',  'application/json',
--           'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
--         ),
--         body    := jsonb_build_object('mode', 'daily_report_cron')
--       );
--     $cron$
--   );
--
-- The edge function, when invoked with {"mode":"daily_report_cron"}, iterates
-- companies where whatsapp_preferences.daily_report_enabled = TRUE and sends
-- the approved daily-report template to each recipient.
-- ============================================================

-- ============================================================
-- Next (Phase 2): inbound webhook for delivery receipts + opt-out handling.
-- ============================================================
