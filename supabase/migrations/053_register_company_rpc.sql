-- ============================================================
-- 053_register_company_rpc.sql — atomic self-service company signup
-- ============================================================
-- Used by the SiteOS register screen (Linear AKS-65). After a builder signs up
-- (Supabase Auth creates the auth user + the on-signup trigger creates a
-- user_profiles row), the client calls this RPC to atomically:
--   1. create the company (owner = caller, plan defaults to 'trial')
--   2. promote the caller's profile to 'admin' and link it to the company
--
-- One transaction → no partial state if either step fails. SECURITY DEFINER so
-- it can insert into companies under RLS. Depends on 052_saas_foundation.sql.
-- ============================================================

CREATE OR REPLACE FUNCTION public.register_company(
  p_name      text,
  p_gstin     text DEFAULT NULL,
  p_full_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_company_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF coalesce(trim(p_name), '') = '' THEN
    RAISE EXCEPTION 'Company name is required';
  END IF;

  -- One company per user (idempotency guard against double-submit).
  IF EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE id = v_uid AND company_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'User already belongs to a company';
  END IF;

  INSERT INTO public.companies (name, gstin, owner_id)
  VALUES (trim(p_name), NULLIF(trim(p_gstin), ''), v_uid)
  RETURNING id INTO v_company_id;

  UPDATE public.user_profiles
     SET company_id = v_company_id,
         role       = 'admin',
         full_name  = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
         updated_at = now()
   WHERE id = v_uid;

  RETURN v_company_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_company(text, text, text) TO authenticated;
