-- ============================================================================
-- 063_ai.sql — AI Suite (Linear AKS-75..79: AI Suite, Phase 2, Gemini)
-- ----------------------------------------------------------------------------
-- Persists AI chat history per tenant so the assistant keeps conversational
-- context across sessions. Every other AI surface (invoice OCR, daily report,
-- BOQ wizard, voice report) is stateless and runs entirely through Edge
-- Functions, so this migration only needs the chat-history table.
--
-- Multi-tenancy: every row carries company_id REFERENCES companies(id) and is
-- protected by RLS filtering on public.current_company_id() (helper from
-- migration 052_saas_foundation.sql).
-- Idempotent: safe to re-run.
-- ============================================================================

-- 1. ai_chat_messages — one row per chat turn (user question / AI answer) ----
CREATE TABLE IF NOT EXISTS public.ai_chat_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 'user' = question typed by a person, 'assistant' = Gemini reply.
  role        TEXT NOT NULL DEFAULT 'user'
                CHECK (role IN ('user', 'assistant')),
  content     TEXT NOT NULL,
  -- Optional structured context the model used / produced (data snapshot, etc).
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast history fetch: newest-first per tenant + user.
CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_company_user_created
  ON public.ai_chat_messages (company_id, user_id, created_at DESC);

-- 2. Row Level Security ------------------------------------------------------
ALTER TABLE public.ai_chat_messages ENABLE ROW LEVEL SECURITY;

-- Members read every chat row inside their own company.
DROP POLICY IF EXISTS "ai_chat read own company" ON public.ai_chat_messages;
CREATE POLICY "ai_chat read own company" ON public.ai_chat_messages
  FOR SELECT
  USING (company_id = public.current_company_id());

-- Members insert chat rows only into their own company, authored by themselves.
DROP POLICY IF EXISTS "ai_chat insert own company" ON public.ai_chat_messages;
CREATE POLICY "ai_chat insert own company" ON public.ai_chat_messages
  FOR INSERT
  WITH CHECK (
    company_id = public.current_company_id()
    AND user_id = auth.uid()
  );

-- Members delete only their own chat rows (e.g. "clear my history").
DROP POLICY IF EXISTS "ai_chat delete own rows" ON public.ai_chat_messages;
CREATE POLICY "ai_chat delete own rows" ON public.ai_chat_messages
  FOR DELETE
  USING (
    company_id = public.current_company_id()
    AND user_id = auth.uid()
  );

-- 3. updated_at trigger (reuse the global helper if it exists from 052) -------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS trg_ai_chat_messages_updated_at ON public.ai_chat_messages;
    CREATE TRIGGER trg_ai_chat_messages_updated_at
      BEFORE UPDATE ON public.ai_chat_messages
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;
