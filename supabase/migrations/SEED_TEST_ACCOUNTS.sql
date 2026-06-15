-- ============================================================
-- SITEOS TEST ACCOUNTS SEED
-- Run this in: Supabase SQL Editor
-- Project: pennxpaodlpkfzzpiuwp
--
-- Creates:
--   1 company + 4 users (superAdmin / admin / siteManager / client)
--   1 sample project assigned to the site manager
--
-- Login credentials after running:
--   superadmin@siteos.test  /  SiteOS@123
--   admin@siteos.test       /  SiteOS@123
--   manager@siteos.test     /  SiteOS@123
--   client@siteos.test      /  SiteOS@123
-- ============================================================

DO $$
DECLARE
  v_company_id   UUID := 'c0000001-0000-0000-0000-000000000001';
  v_super_id     UUID := 'a0000001-0000-0000-0000-000000000001';
  v_admin_id     UUID := 'a0000002-0000-0000-0000-000000000002';
  v_manager_id   UUID := 'a0000003-0000-0000-0000-000000000003';
  v_client_id    UUID := 'a0000004-0000-0000-0000-000000000004';
  v_project_id   UUID := 'b0000001-0000-0000-0000-000000000001';
  v_password     TEXT := crypt('SiteOS@123', gen_salt('bf'));
BEGIN

-- ── 1. Company ───────────────────────────────────────────────
-- plan: 'trial'|'starter'|'professional'|'enterprise'
-- sub_status: 'trialing'|'active'|'past_due'|'canceled'|'expired'
INSERT INTO public.companies (id, name, plan, trial_ends_at, sub_status, created_at)
VALUES (v_company_id, 'Aksha Construction Pvt Ltd', 'professional', NOW() + INTERVAL '1 year', 'active', NOW())
ON CONFLICT (id) DO NOTHING;

-- ── 2a. Auth users ────────────────────────────────────────────
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
  (v_super_id,   '00000000-0000-0000-0000-000000000000', 'superadmin@siteos.test', v_password, NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Super Admin"}',                'authenticated', 'authenticated', NOW(), NOW(), '', '', '', ''),
  (v_admin_id,   '00000000-0000-0000-0000-000000000000', 'admin@siteos.test',      v_password, NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Admin User"}',                 'authenticated', 'authenticated', NOW(), NOW(), '', '', '', ''),
  (v_manager_id, '00000000-0000-0000-0000-000000000000', 'manager@siteos.test',    v_password, NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Rajesh Kumar"}',               'authenticated', 'authenticated', NOW(), NOW(), '', '', '', ''),
  (v_client_id,  '00000000-0000-0000-0000-000000000000', 'client@siteos.test',     v_password, NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Amit Shah (Builder Client)"}', 'authenticated', 'authenticated', NOW(), NOW(), '', '', '', '')
ON CONFLICT (id) DO NOTHING;

-- ── 2b. Auth identities (required for email/password login) ──
-- GoTrue resolves email logins via auth.identities; missing rows → 400.
INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
VALUES
  (v_super_id,   'superadmin@siteos.test', v_super_id,   jsonb_build_object('sub', v_super_id::text,   'email', 'superadmin@siteos.test', 'email_verified', true, 'phone_verified', false), 'email', NOW(), NOW(), NOW()),
  (v_admin_id,   'admin@siteos.test',      v_admin_id,   jsonb_build_object('sub', v_admin_id::text,   'email', 'admin@siteos.test',      'email_verified', true, 'phone_verified', false), 'email', NOW(), NOW(), NOW()),
  (v_manager_id, 'manager@siteos.test',    v_manager_id, jsonb_build_object('sub', v_manager_id::text, 'email', 'manager@siteos.test',    'email_verified', true, 'phone_verified', false), 'email', NOW(), NOW(), NOW()),
  (v_client_id,  'client@siteos.test',     v_client_id,  jsonb_build_object('sub', v_client_id::text,  'email', 'client@siteos.test',     'email_verified', true, 'phone_verified', false), 'email', NOW(), NOW(), NOW())
ON CONFLICT (provider, provider_id) DO NOTHING;

-- ── 3. User profiles ─────────────────────────────────────────
-- role: 'super_admin'|'admin'|'site_manager'|'client'
INSERT INTO public.user_profiles (id, email, full_name, role, company_id, phone, created_at)
VALUES
  (v_super_id,   'superadmin@siteos.test', 'Super Admin',                'super_admin',  v_company_id, '9000000001', NOW()),
  (v_admin_id,   'admin@siteos.test',      'Admin User',                 'admin',        v_company_id, '9000000002', NOW()),
  (v_manager_id, 'manager@siteos.test',    'Rajesh Kumar',               'site_manager', v_company_id, '9000000003', NOW()),
  (v_client_id,  'client@siteos.test',     'Amit Shah (Builder Client)', 'client',       v_company_id, '9000000004', NOW())
ON CONFLICT (id) DO UPDATE
  SET role = EXCLUDED.role,
      company_id = EXCLUDED.company_id,
      email = EXCLUDED.email;

-- ── 4. Sample project ────────────────────────────────────────
-- projects only has: id, name, description, location, status,
--   start_date, end_date, budget, created_by, created_at, updated_at
INSERT INTO public.projects (id, name, location, status, created_by, created_at)
VALUES (v_project_id, 'Skyline Residency — Phase 1', 'Andheri West, Mumbai', 'in_progress', v_admin_id, NOW())
ON CONFLICT (id) DO NOTHING;

-- ── 5. Assign site manager to project ───────────────────────
-- project_assignments: project_id, user_id, assigned_role, assigned_at, assigned_by
INSERT INTO public.project_assignments (project_id, user_id, assigned_role, assigned_by, assigned_at)
VALUES (v_project_id, v_manager_id, 'manager', v_admin_id, NOW())
ON CONFLICT (project_id, user_id) DO NOTHING;

-- ── 6. Grant client access to project ───────────────────────
-- client_project_access: client_user_id, project_id, company_id  (no granted_by)
INSERT INTO public.client_project_access (client_user_id, project_id, company_id, created_at)
VALUES (v_client_id, v_project_id, v_company_id, NOW())
ON CONFLICT (client_user_id, project_id) DO NOTHING;

-- ── 7. Sample suppliers ──────────────────────────────────────
INSERT INTO public.suppliers (name, category, phone, is_active, created_by, created_at)
VALUES
  ('Ram Steel Traders',   'Steel',   '9111111111', true, v_admin_id, NOW()),
  ('Shree Cement Agency', 'Cement',  '9222222222', true, v_admin_id, NOW()),
  ('Vijay Hardware',      'Hardware','9333333333', true, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

-- ── 8. Sample stock items ────────────────────────────────────
-- stock_items.created_by references user_profiles(id)
-- grade and low_stock_threshold added by migration 030
INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, low_stock_threshold, created_by, created_at)
VALUES
  (v_project_id, 'TMT Steel Bar',    'Fe500',    'MT',  0,   5, v_admin_id, NOW()),
  (v_project_id, 'OPC Cement',       '53 Grade', 'Bag', 0,  50, v_admin_id, NOW()),
  (v_project_id, 'River Sand',       NULL,       'CFT', 0, 100, v_admin_id, NOW()),
  (v_project_id, 'Coarse Aggregate', '20mm',     'CFT', 0, 200, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

RAISE NOTICE '==============================================';
RAISE NOTICE 'Test accounts created successfully!';
RAISE NOTICE 'superadmin@siteos.test  /  SiteOS@123  (Super Admin)';
RAISE NOTICE 'admin@siteos.test       /  SiteOS@123  (Admin)';
RAISE NOTICE 'manager@siteos.test     /  SiteOS@123  (Site Manager)';
RAISE NOTICE 'client@siteos.test      /  SiteOS@123  (Client)';
RAISE NOTICE 'Company : Aksha Construction Pvt Ltd  (plan: professional)';
RAISE NOTICE 'Project : Skyline Residency — Phase 1';
RAISE NOTICE '==============================================';

END $$;
