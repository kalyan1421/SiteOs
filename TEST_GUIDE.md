# SiteOS — Test Guide

## 1. Create Test Accounts

Run these SQL statements in the **Supabase SQL Editor** (project `pennxpaodlpkfzzpiuwp`) to create test users. Replace passwords as needed.

```sql
-- Step 1: Create a company first
INSERT INTO public.companies (id, name, plan, plan_expires_at)
VALUES (
  'aaaaaaaa-0000-0000-0000-000000000001',
  'Test Construction Co.',
  'growth',
  NOW() + INTERVAL '1 year'
);

-- Step 2: Create users via Supabase Auth (do this in Auth > Users > Add User)
-- Then insert their profiles below after getting the auth UUIDs.

-- After creating auth users, insert profiles:
INSERT INTO public.user_profiles (id, email, full_name, role, company_id) VALUES
  ('<super-admin-uuid>', 'superadmin@test.com', 'Super Admin',  'super_admin',  'aaaaaaaa-0000-0000-0000-000000000001'),
  ('<admin-uuid>',       'admin@test.com',      'Admin User',   'admin',        'aaaaaaaa-0000-0000-0000-000000000001'),
  ('<manager-uuid>',     'manager@test.com',    'Site Manager', 'site_manager', 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('<client-uuid>',      'client@test.com',     'Client User',  'client',       'aaaaaaaa-0000-0000-0000-000000000001');

-- Grant client access to a project (after creating a project as admin)
INSERT INTO public.client_project_access (client_user_id, project_id, granted_by)
VALUES ('<client-uuid>', '<project-uuid>', '<admin-uuid>');
```

---

## 2. Role Matrix

| Feature | Super Admin | Admin | Site Manager | Client |
|---|:---:|:---:|:---:|:---:|
| Login → dashboard | ✅ | ✅ | ✅ | ✅ |
| Create project | ✅ | ✅ | ✗ | ✗ |
| View all projects | ✅ | ✅ | assigned only | assigned only |
| Edit project | ✅ | ✅ | ✗ | ✗ |
| Delete project (soft) | ✅ | ✅ | ✗ | ✗ |
| Materials / Stock | ✅ | ✅ | ✅ | ✗ |
| Approve bills | ✅ | ✅ | ✗ | ✗ |
| Raise bills | ✅ | ✅ | ✅ | ✗ |
| View bills | ✅ | ✅ | ✅ | read-only |
| Blueprints upload | ✅ | ✅ | ✅ | ✗ |
| Blueprints view | ✅ | ✅ | ✅ | ✅ (read-only) |
| Labour management | ✅ | ✅ | ✅ | ✗ |
| Machinery logs | ✅ | ✅ | ✅ | ✗ |
| GPS check-in | ✅ | ✅ | ✅ | ✗ |
| Reports | ✅ | ✅ | ✗ | ✗ |
| BOQ | ✅ | ✅ | view | ✗ |
| RA Billing / GST | ✅ | ✅ | ✗ | ✗ |
| QA / Snag lists | ✅ | ✅ | ✅ | ✗ |
| Purchase Indents | ✅ | ✅ | ✅ | ✗ |
| Purchase Orders | ✅ | ✅ | view | ✗ |
| RERA Reports | ✅ | ✅ | ✗ | ✗ |
| Subcontractors | ✅ | ✅ | view | ✗ |
| AI features | ✅ | ✅ | ✅ | ✗ |
| WhatsApp settings | ✅ | ✅ | ✗ | ✗ |
| Manage site managers | ✅ | ✅ | ✗ | ✗ |
| Staff directory | ✅ | ✅ | ✗ | ✗ |
| Company settings | ✅ | ✗ | ✗ | ✗ |

---

## 3. Feature Checklist

### Auth
- [ ] Login with `superadmin@test.com` → lands on `/super-admin/dashboard`
- [ ] Login with `admin@test.com` → lands on `/admin/dashboard`
- [ ] Login with `manager@test.com` → lands on `/site-manager/dashboard`
- [ ] Login with `client@test.com` → lands on `/client/dashboard`
- [ ] Client role: manually navigate to `/projects` → redirected back to `/client/dashboard`
- [ ] Forgot password → email received
- [ ] Sign out → session cleared, redirected to `/login`
- [ ] Wrong password → shake animation + error message
- [ ] Login with deleted/missing profile → sign-out (no silent siteManager grant)

### Projects
- [ ] Admin: create project (name, location, type, client name, start date)
- [ ] Admin: edit project details
- [ ] Admin: soft-delete project (disappears from list)
- [ ] Site Manager: see only assigned projects
- [ ] Project detail: shows progress %, status, team members
- [ ] Project photos: upload geotagged photo from site

### Materials & Stock
- [ ] Add material receipt: select supplier, material name, grade, qty, unit, price, payment type
- [ ] Consume material: deducts from stock
- [ ] Stock ledger: shows inward/outward/balance per material per project
- [ ] Low-stock alert triggers when balance ≤ threshold
- [ ] Material master: global material name suggestions appear while typing

### Bills
- [ ] Site Manager raises a bill (advance/part/full)
- [ ] Bill appears in admin approval queue
- [ ] Admin approves bill → status changes
- [ ] Admin rejects bill → moved to bin
- [ ] Bills bin: restore or permanently delete
- [ ] PDF view of bill attachment

### Blueprints
- [ ] Upload PDF blueprint to a project folder
- [ ] View blueprint in in-app PDF viewer
- [ ] Create folder structure per project
- [ ] Client user: can view blueprints (read-only, no upload button)

### Labour
- [ ] Add worker to project (name, trade, daily wage)
- [ ] Mark attendance (present/absent/half-day)
- [ ] Daily labour log: confirm count matches marked attendance
- [ ] Labour master: global worker pool

### Machinery
- [ ] Add machine (name, type, ownership: owned/rented)
- [ ] Log machinery usage (hours/reading-based)
- [ ] Time-based log: start time, end time, hours computed
- [ ] Reading-based log: start reading, end reading

### GPS Attendance
- [ ] Admin sets geofence: tap map to set centre + radius for a project
- [ ] Site Manager opens check-in screen: sees current GPS coordinates
- [ ] Check-in within geofence: succeeds
- [ ] Check-in outside geofence: blocked with distance shown

### BOQ
- [ ] Create BOQ for a project
- [ ] Add line items (description, unit, estimated qty, rate)
- [ ] BOQ vs Actual view: compare estimated vs consumed materials

### RA Billing / GST
- [ ] Create RA bill for a project (running account billing)
- [ ] Add work items with % completion
- [ ] GST config: set GSTIN, tax rates
- [ ] Export Tally XML → download `.xml` file

### QA / Snag Lists
- [ ] Create checklist template (e.g., "Plastering Inspection")
- [ ] Apply template to a project
- [ ] Mark items pass/fail with photo evidence
- [ ] Create snag: description, location, assigned to, photo
- [ ] Snag status: open → in progress → resolved

### Purchase Orders
- [ ] Site Manager raises material indent (item, qty, unit, project)
- [ ] Admin approves indent → creates PO
- [ ] PO detail: vendor, items, value, status
- [ ] GRN: receive against PO → stock updated

### RERA
- [ ] Create RERA report for a project
- [ ] Fill quarterly data: completion %, floor-wise progress
- [ ] Attach geotagged photos as evidence
- [ ] Export PDF in RERA format

### Subcontractors
- [ ] Add subcontractor (name, GSTIN, specialization)
- [ ] Create work order (scope, value, retention %, TDS %)
- [ ] Add RA bill against work order
- [ ] Verify TDS and retention deductions shown

### AI Features (requires Gemini API key in Edge Functions)
- [ ] AI Daily Report: auto-generate site report from labour/material data
- [ ] AI BOQ: paste project description → generates BOQ line items
- [ ] AI Invoice OCR: photograph a bill → fields auto-fill
- [ ] AI Chat: ask "how many bags of cement received this week?"
- [ ] Voice Report: speak in Hindi → transcribed to site report

### WhatsApp
- [ ] Configure WhatsApp Business API (phone number ID + access token)
- [ ] Send daily report via WhatsApp to project group
- [ ] Receive message notification in app

### Client Portal
- [ ] Client login → sees only projects granted access to
- [ ] Client: view project progress % and milestone timeline
- [ ] Client: view site photos (read-only gallery)
- [ ] Client: view RA bill status (no edit/approve buttons visible)
- [ ] Client: try URL `/projects` → redirected to `/client/dashboard`

### Reports
- [ ] Materials report: total inward/outward/balance per project
- [ ] Labour report: attendance summary, wage total
- [ ] Bill report: total bills, approved vs pending
- [ ] Line chart: daily material inflow over time
- [ ] Pie chart: bill breakdown by type
- [ ] Bar chart: project-wise labour cost

### Settings
- [ ] Language toggle: English ↔ Hindi (UI strings change)
- [ ] Profile: update name, phone, avatar

---

## 4. Security Tests

| Test | Expected |
|---|---|
| Client navigates to `/admin/dashboard` | Redirected to `/client/dashboard` |
| Client navigates to `/projects` | Redirected to `/client/dashboard` |
| Site Manager navigates to `/admin/site-managers` | Redirected to `/site-manager/dashboard` |
| Login with user who has no DB profile row | Forced sign-out, error message shown |
| Login with deleted user (valid session, no profile) | Forced sign-out |
| Expired plan | All features locked, plan expired screen shown |
| Direct URL to `/super-admin/dashboard` as admin | Redirected to `/admin/dashboard` |

---

## 5. Test Data Quick-Start SQL

Paste this in SQL Editor after creating auth users:

```sql
-- Sample project
INSERT INTO public.projects (id, name, location, status, company_id, created_by)
VALUES (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'Test Tower — Mumbai',
  'Andheri West, Mumbai',
  'in_progress',
  'aaaaaaaa-0000-0000-0000-000000000001',
  '<admin-uuid>'
);

-- Assign site manager to project
INSERT INTO public.project_assignments (project_id, user_id, assigned_by)
VALUES (
  'bbbbbbbb-0000-0000-0000-000000000001',
  '<manager-uuid>',
  '<admin-uuid>'
);

-- Sample supplier
INSERT INTO public.suppliers (name, category, phone, created_by)
VALUES ('Ram Steel Works', 'Steel', '9876543210', '<admin-uuid>');

-- Sample stock item
INSERT INTO public.stock_items (project_id, name, grade, unit, quantity, created_by)
VALUES (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'TMT Steel Bar', 'Fe500', 'MT', 0, '<admin-uuid>'
);
```

---

## 6. Known Skipped Migrations

These files are skipped by `supabase db push` (non-numeric filename prefix):

| File | Contents folded into |
|---|---|
| `017b_suppliers_table.sql` | `026_vendor_material_totals.sql` |
| `050b_set_projects_active.sql` | Apply manually if needed |

To apply `050b` manually, run it in Supabase SQL Editor.
