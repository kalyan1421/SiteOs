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

-- ── Fixed UUIDs (predictable for follow-up queries) ─────────
DO $$
DECLARE
  v_company_id   UUID := 'c0000001-0000-0000-0000-000000000001';
  v_super_id     UUID := 'u0000001-0000-0000-0000-000000000001';
  v_admin_id     UUID := 'u0000002-0000-0000-0000-000000000002';
  v_manager_id   UUID := 'u0000003-0000-0000-0000-000000000003';
  v_client_id    UUID := 'u0000004-0000-0000-0000-000000000004';
  v_project_id   UUID := 'p0000001-0000-0000-0000-000000000001';
  v_password     TEXT := crypt('SiteOS@123', gen_salt('bf'));
BEGIN

-- ── 1. Company ───────────────────────────────────────────────
INSERT INTO public.companies (
  id, name, plan, plan_expires_at, max_projects, max_users, created_at
) VALUES (
  v_company_id,
  'Aksha Construction Pvt Ltd',
  'growth',
  NOW() + INTERVAL '1 year',
  10,
  20,
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- ── 2. Auth users (Supabase auth.users) ─────────────────────

-- Super Admin
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  v_super_id,
  '00000000-0000-0000-0000-000000000000',
  'superadmin@siteos.test',
  v_password,
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Super Admin"}',
  'authenticated', 'authenticated',
  NOW(), NOW(),
  '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

-- Admin
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  v_admin_id,
  '00000000-0000-0000-0000-000000000000',
  'admin@siteos.test',
  v_password,
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Admin User"}',
  'authenticated', 'authenticated',
  NOW(), NOW(),
  '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

-- Site Manager
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  v_manager_id,
  '00000000-0000-0000-0000-000000000000',
  'manager@siteos.test',
  v_password,
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Rajesh Kumar"}',
  'authenticated', 'authenticated',
  NOW(), NOW(),
  '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

-- Client
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  v_client_id,
  '00000000-0000-0000-0000-000000000000',
  'client@siteos.test',
  v_password,
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Amit Shah (Builder Client)"}',
  'authenticated', 'authenticated',
  NOW(), NOW(),
  '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

-- ── 3. User profiles ─────────────────────────────────────────
INSERT INTO public.user_profiles (id, email, full_name, role, company_id, phone, created_at)
VALUES
  (v_super_id,   'superadmin@siteos.test', 'Super Admin',              'super_admin',  v_company_id, '9000000001', NOW()),
  (v_admin_id,   'admin@siteos.test',      'Admin User',               'admin',        v_company_id, '9000000002', NOW()),
  (v_manager_id, 'manager@siteos.test',    'Rajesh Kumar',             'site_manager', v_company_id, '9000000003', NOW()),
  (v_client_id,  'client@siteos.test',     'Amit Shah (Builder Client)', 'client',     v_company_id, '9000000004', NOW())
ON CONFLICT (id) DO UPDATE
  SET role = EXCLUDED.role,
      company_id = EXCLUDED.company_id;

-- ── 4. Sample project ────────────────────────────────────────
INSERT INTO public.projects (
  id, name, location, status, progress, project_type,
  client_name, company_id, created_by, created_at
) VALUES (
  v_project_id,
  'Skyline Residency — Phase 1',
  'Andheri West, Mumbai',
  'in_progress',
  35,
  'Residential',
  'Amit Shah',
  v_company_id,
  v_admin_id,
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- ── 5. Assign site manager to project ───────────────────────
INSERT INTO public.project_assignments (project_id, user_id, assigned_by, created_at)
VALUES (v_project_id, v_manager_id, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

-- ── 6. Grant client access to project ───────────────────────
INSERT INTO public.client_project_access (client_user_id, project_id, granted_by, created_at)
VALUES (v_client_id, v_project_id, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

-- ── 7. Sample supplier ───────────────────────────────────────
INSERT INTO public.suppliers (name, category, phone, is_active, created_by, created_at)
VALUES
  ('Ram Steel Traders',   'Steel',   '9111111111', true, v_admin_id, NOW()),
  ('Shree Cement Agency', 'Cement',  '9222222222', true, v_admin_id, NOW()),
  ('Vijay Hardware',      'Hardware','9333333333', true, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

-- ── 8. Sample stock items ────────────────────────────────────
INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, low_stock_threshold, created_by, created_at)
VALUES
  (v_project_id, 'TMT Steel Bar',  'Fe500', 'MT',   0, 5,   v_admin_id, NOW()),
  (v_project_id, 'OPC Cement',     '53 Grade', 'Bag', 0, 50, v_admin_id, NOW()),
  (v_project_id, 'River Sand',     NULL,    'CFT',  0, 100, v_admin_id, NOW()),
  (v_project_id, 'Coarse Aggregate', '20mm', 'CFT', 0, 200, v_admin_id, NOW())
ON CONFLICT DO NOTHING;

RAISE NOTICE '==============================================';
RAISE NOTICE 'Test accounts created successfully!';
RAISE NOTICE '';
RAISE NOTICE 'superadmin@siteos.test  /  SiteOS@123  (Super Admin)';
RAISE NOTICE 'admin@siteos.test       /  SiteOS@123  (Admin)';
RAISE NOTICE 'manager@siteos.test     /  SiteOS@123  (Site Manager)';
RAISE NOTICE 'client@siteos.test      /  SiteOS@123  (Client)';
RAISE NOTICE '';
RAISE NOTICE 'Company : Aksha Construction Pvt Ltd';
RAISE NOTICE 'Project : Skyline Residency — Phase 1';
RAISE NOTICE 'Plan    : growth  (expires 1 year from now)';
RAISE NOTICE '==============================================';

END $$;
