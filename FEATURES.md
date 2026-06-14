# SiteOS — Application Features

**App:** SiteOS (Civil Construction Management)
**Platform:** Flutter (Android, iOS) + Supabase backend + Firebase (Crashlytics / messaging)
**Architecture:** Feature-based modules, Repository pattern, Riverpod state management
**Backend:** Supabase (PostgreSQL + RLS + Realtime + Storage + Edge Functions)
**Offline:** Hive local cache + offline mutation queue + connectivity-driven sync
**Bundle ID:** `com.clivimanagement.app`

> Document last updated: 2026-06-13

---

## Table of Contents

1. [User Roles & Access Model](#1-user-roles--access-model)
2. [Authentication](#2-authentication)
3. [Dashboards](#3-dashboards)
4. [User & Staff Management](#4-user--staff-management)
5. [Projects](#5-projects)
6. [Bills & Payments](#6-bills--payments)
7. [Materials & Inventory](#7-materials--inventory)
8. [Labour & Attendance](#8-labour--attendance)
9. [Machinery](#9-machinery)
10. [Vendors / Suppliers](#10-vendors--suppliers)
11. [Blueprints & Documents](#11-blueprints--documents)
12. [Reports & Analytics](#12-reports--analytics)
13. [Profile](#13-profile)
14. [Core Platform Capabilities](#14-core-platform-capabilities)
15. [Data Model Summary](#15-data-model-summary)
16. [Route Map](#16-route-map)
17. [Feature × Role Matrix](#17-feature--role-matrix)
18. [Pending / Planned Features](#18-pending--planned-features)

---

## 1. User Roles & Access Model

The app has **three role tiers**. Access is enforced both at the router level (role-based redirects) and at the database level (Supabase Row-Level Security).

| Role | Key | Scope |
|------|-----|-------|
| **Super Admin** | `super_admin` | Full system control; admin management; highest privilege |
| **Admin** | `admin` | Manage projects, site managers, master data, bill approvals, reports |
| **Site Manager** | `site_manager` | Operate only on **assigned projects** — attendance, daily logs, material/machinery operations, bill creation |

**Access rules:**
- Super Admin routes (`/super-admin/*`) — `super_admin` only.
- Admin routes (`/admin/*`, `/master/*`, `/reports`, `/bills/approval-queue`, `/bills/bin`, project create/edit) — `admin` and above.
- Site Manager — restricted to projects assigned via `project_assignments`; RLS + query filtering hide other projects' data.
- New self-registered users default to `site_manager`.

---

## 2. Authentication

**Module:** `lib/features/auth/`

**Screens:** Splash, Login, Forgot Password

**Features:**
- Email / password login with form validation and progress feedback.
- Session check on startup (splash screen) → routes to the role-appropriate dashboard.
- Password reset via email.
- Sign up / new user registration (defaults to `site_manager` role).
- **Admin-initiated user creation** through the `create-site-manager` Edge Function, which uses the service-role key server-side so the admin's own session is never disturbed.
- **Admin user deletion** via `admin_delete_user` RPC (cascades to `user_profiles`).
- Token auto-refresh (~55-minute interval) via Session Manager.
- Sign-out clears all per-user local caches.

**Validation rules:** Email regex; password 8–128 chars; name 2–100 chars; file uploads max 10 MB.

---

## 3. Dashboards

**Module:** `lib/features/dashboard/`

Each role gets a tailored dashboard. All connect to the global realtime sync provider for live updates.

### Super Admin Dashboard
- Welcome header, system-access confirmation, logout.
- Currently minimal — placeholder for future admin-of-admins tooling.

### Admin Dashboard
- **KPI stat cards:** total projects, active projects, total expenses, labour cost, material cost, machinery cost.
- **Attention hero:** pending bills, overdue tasks, alerts.
- **Quick actions grid:** Projects, Bills, Materials, Labour, Machinery, Suppliers, Reports.
- **Active projects list** with status, assigned manager, progress.
- **Recent operations log:** latest bills, material receipts, attendance.
- Realtime live counters.

### Site Manager Dashboard
- Personalized welcome.
- Stats filtered to **assigned projects only**.
- Operations grid for relevant day-to-day actions.
- Assigned active projects list and a filtered recent-activity feed.

---

## 4. User & Staff Management

**Module:** `lib/features/dashboard/` (admin management screens)
**Access:** Admin and above.

**Screens & features:**
- **Add Site Manager** — create a site manager (email, password, full name, phone, position, address) via the secure Edge Function.
- **Site Manager Management** — list, edit, and delete site managers.
- **Edit Site Manager** — update details.
- **Staff Directory** — view all staff with contact info.

---

## 5. Projects

**Module:** `lib/features/projects/`

**Screens:** Project List, Project Detail, Create/Edit Project, Project Operations hub, Project Site Photos.

**Features:**
- Paginated project list (20/page, infinite scroll) with search and filters.
- **Create / edit / delete** projects (admin+ only; delete is soft-delete via `deletedAt`).
- View full project detail with all linked data.
- **Assign site managers** to projects (`project_assignments`).
- Status lifecycle: `planning → in_progress → on_hold → completed → cancelled`.
- Progress tracking (0–100%), budget (₹), start/end dates.
- Project types: Residential, Commercial, Infrastructure, Industrial.
- **Operations hub** linking each project to Materials, Machinery, and Labour tabs.
- **Site photos** — upload project progress photos (`project-images` bucket).

Site managers see and operate only on their assigned projects; admins see and create all.

---

## 6. Bills & Payments

**Module:** `lib/features/bills/`

**Screens:** Bills (Pending / Completed tabs), Create Bill, Admin Approval Queue, Bills Bin (recycle).

**Features:**
- Create bills with **attachments** (camera capture or file picker).
- Bill types: workers, materials, transport, equipment rent, expense, income, invoice, advance, part payment, full payment, petty cash.
- Status flow: `pending → approved → paid → completed` (or `rejected`).
- Payment status: need-to-pay, advance, half-paid, full-paid.
- Payment types: cash, UPI, bank transfer, cheque.
- **Date / type / payment filters** and search.
- **Approval workflow:** site manager creates → approval queue → admin approves/rejects with comments → payment recorded. (Approval queue & bin are admin-only.)
- **Export bills to PDF.**
- **Soft delete → Bills Bin**; hard delete (admin only).
- Material receipts auto-generate corresponding bills.
- Role filtering: admin sees all bills; site managers see bills for their own projects.

---

## 7. Materials & Inventory

**Modules:** `lib/features/inventory/` + `lib/features/materials/`

### Inventory (per-project stock)
**Screens:** Stock List, Daily Material Log, Supplier List.
- Current stock per project, grouped by material with **low-stock alerts**.
- Inward / outward transaction log.
- Units: units, tonnes, cubic metres, litres, etc.

### Materials (advanced operations)
**Screens:** Material Master List, Materials Tab (by material / by vendor), Material Receive (GRN), Material Consume, Stock Ledger, Receipt Detail.
- **Material master library** — central material catalogue (admin CRUD).
- **Material receipt / GRN** — record goods received from a supplier (items, quantities, rates, total). Completion **auto-creates a bill**.
- **Material consumption** — log outward usage per project.
- **Stock ledger** — inward vs outward vs current balance per project per material.
- **Vendor totals** — aggregate quantity supplied per supplier.
- Receipt detail view with attachments (`receipts` bucket).

---

## 8. Labour & Attendance

**Module:** `lib/features/labour/`

**Screens:** Labour Master, Labour Roster, Labour Tab, Attendance.

**Features:**
- **Labour master** — global worker registry (name, phone, skill type, daily wage); admin CRUD.
- Skill types: Mason, Carpenter, Electrician, Plumber, Painter, Welder, Helper, Supervisor, Driver, Crane Operator, etc.
- **Project roster** — assign workers to a project with quick access to attendance.
- **Daily attendance** — grid view (worker × date); mark present / absent / half-day / leave.
- Bulk-mark attendance across a date range.
- Daily labour logs and a normalized attendance view.

---

## 9. Machinery

**Module:** `lib/features/machinery/`

**Screens:** Machinery Master, Machinery Tab (per-project usage), Machinery Log.

**Features:**
- **Machinery master** — equipment registry (name, type, registration no., status, ownership Own/Rental); admin CRUD.
- Equipment types: Excavator, JCB, Crane, Mixer, etc.
- Status: active / inactive / maintenance.
- **Usage logging** — start/end reading, hours used, operator, cost, date.
- Track total hours and current reading per machine.
- Temporary assignment to projects.
- Per-project usage log with date-range filter.

---

## 10. Vendors / Suppliers

**Module:** `lib/features/vendors/`

**Screens:** Vendors List, Vendor Analytics Dashboard, Vendor Detail Totals.

**Features:**
- **Supplier master** — name, contact person, phone, email, address, category (Cement, Steel, Sand, Labour, Transport, etc.); admin CRUD.
- **Vendor analytics** — total materials supplied, total amount (₹), aggregate quantity, last transaction.
- Vendor-specific totals view (total supplied, pending payments).

---

## 11. Blueprints & Documents

**Module:** `lib/features/blueprints/`

**Screens:** Blueprint Files browser, Blueprint Upload, Blueprint Viewer, Folders.

**Features:**
- Folder/file browser with search.
- **Upload** blueprints — PDF, DWG, DXF, JPG, PNG (max 10 MB each); multi-file with progress (admin only).
- **In-app viewer** for PDFs and images.
- **Delete** (admin only).
- Stored in the Supabase `blueprints` bucket with role-enforcing storage policies.
- Site managers can view all blueprints for accessible projects.

---

## 12. Reports & Analytics

**Module:** `lib/features/reports/`
**Access:** Admin and above.

**Screens:** Reports.

**Features:**
- **Financial summary** — total expenses broken down by labour, material, machinery, and other costs.
- **Monthly breakdown chart** (trend visualization).
- **Vendor analytics table.**
- **Multi-page PDF export** with formatted tables and charts (in-app print preview).
- Scoped to a single project or across all projects.

---

## 13. Profile

**Module:** `lib/features/profile/`
**Access:** All authenticated users.

**Features:**
- Hero card (avatar, name, role, email).
- Edit contact info (phone, position, address).
- **Change password.**
- View role & permissions (read-only).
- App info (version, build date).
- Quick links (admins → staff directory).
- Sign out (clears per-user caches).

---

## 14. Core Platform Capabilities

**Module:** `lib/core/`

- **Offline-first caching (Hive):** projects, user profile, metadata cached locally; SWR-style refresh; cleared on sign-out.
- **Offline mutation queue:** queues writes (bills, attendance, stock transactions) while offline and auto-flushes on reconnect.
- **Connectivity monitoring:** detects network state and triggers queue flush / resync.
- **Realtime sync:** single global Supabase realtime channel subscribed to projects, bills, materials, labour; debounce-invalidates Riverpod providers so the UI updates live. Reconnects on app resume.
- **Session manager:** periodic token refresh and session validation.
- **Notification service:** in-app notification metadata + unread badge, with read/unread deduplication. (Firebase messaging integrated.)
- **Crash reporting:** Firebase Crashlytics.
- **Responsive UI:** desktop (≤1200px panels, side-by-side) and mobile (stacked) layouts.
- **Currency / date formatting:** ₹ (INR, en_IN), 2 decimals; dates `dd/MM/yyyy`.
- **Robust error handling:** typed exceptions (`AppAuthException`, `DatabaseException`), consistent error UI with retry, retry-with-backoff helper.
- **File uploads:** Supabase Storage buckets — `avatars`, `blueprints`, `bills`, `receipts`, `project-images`; 10 MB cap.

---

## 15. Data Model Summary

| Entity | Table | Notes |
|--------|-------|-------|
| User Profile | `user_profiles` | role, name, phone, position, address, avatar |
| Project | `projects` | status, budget, dates, type, progress, soft-delete |
| Project Assignment | `project_assignments` | links site managers to projects |
| Bill | `bills` | type, status, payment status/type, attachment |
| Stock Item | `stock_items` | per-project inventory + low-stock threshold |
| Material Log | `material_logs` | inward/outward transactions |
| Material Master | `material_master` | central material catalogue |
| Material Receipt (GRN) | `material_receipts` | goods received, auto-creates bill |
| Material Consumption | `material_consumptions` | outward usage |
| Stock Balance | `stock_balance` | inward/outward/balance ledger |
| Labour | `labour_records` | global + project workers |
| Labour Attendance | `labour_attendance` / `daily_labour_logs` | present/absent/half-day/leave |
| Machinery | `machinery` | equipment master + usage stats |
| Machinery Log | `machinery_logs` | usage transactions |
| Supplier | `suppliers` | vendor master |
| Blueprint | `blueprints` | files in storage |

**Edge Function:** `create-site-manager` — secure admin-only user creation using the service-role key.

---

## 16. Route Map

```
PUBLIC
  /splash, /login, /forgot-password

SUPER ADMIN
  /super-admin/dashboard

DASHBOARD SHELL (sidebar / bottom nav)
  /admin/dashboard                         (admin+)
  /site-manager/dashboard                  (site_manager+)

  ADMIN MANAGEMENT (admin+)
  /admin/site-managers, /admin/site-managers/add, /admin/staff-directory

  MASTER DATA (admin+)
  /master/vendors, /master/materials, /master/machinery, /master/labour
  /suppliers, /vendors, /machinery

  BILLS
  /bills, /bills/create
  /bills/approval-queue (admin+), /bills/bin (admin+)

  PROJECTS
  /projects (admin+ create), /projects/create (admin+)
  /projects/:id, /projects/:id/edit (admin+)
  /projects/:id/blueprints, /projects/:id/blueprints/view/:fileId
  /projects/:id/stock, /projects/:id/material-log
  /projects/:id/labour, /projects/:id/attendance
  /projects/:id/operations  → materials | machinery | labour
  /projects/:id/materials/receive | consume | stock | receipt/:receiptId
  /projects/:id/machinery/log
  /projects/:id/labour/daily-attendance
  /projects/:id/reports, /projects/:id/photos

  REPORTS & PROFILE
  /reports (admin+), /profile
```

---

## 17. Feature × Role Matrix

| Feature | Super Admin | Admin | Site Manager |
|---------|:----------:|:-----:|:------------:|
| Dashboard | ✅ (own) | ✅ (all) | ✅ (assigned) |
| Manage admins | ✅ | — | — |
| Manage site managers / staff | ✅ | ✅ | — |
| Projects — view | ✅ | ✅ (all) | ✅ (assigned) |
| Projects — create/edit/delete | ✅ | ✅ | — |
| Bills — create/view | ✅ | ✅ (all) | ✅ (own) |
| Bills — approve / bin | ✅ | ✅ | — |
| Materials — master data | ✅ | ✅ | — |
| Materials — receive/consume/ledger | ✅ | ✅ | ✅ (assigned) |
| Labour — master | ✅ | ✅ | — |
| Labour — attendance/roster | ✅ | ✅ | ✅ (assigned) |
| Machinery — master | ✅ | ✅ | — |
| Machinery — usage log | ✅ | ✅ | ✅ (assigned) |
| Vendors — master / analytics | ✅ | ✅ | view |
| Blueprints — upload/delete | ✅ | ✅ | — |
| Blueprints — view | ✅ | ✅ | ✅ |
| Reports | ✅ | ✅ | — |
| Profile | ✅ | ✅ | ✅ |

✅ = available · — = not available · "assigned/own" = scoped data only

---

## 18. Pending / Planned Features

These are not yet implemented (or only partially) and are candidates for the roadmap:

### High priority
- [ ] **Super Admin dashboard build-out** — currently a placeholder; add admin management, org-wide KPIs, audit log view.
- [ ] **Push notifications** — Firebase messaging is wired, but actionable push notifications (bill approvals, low-stock, attendance reminders) are not yet delivered end-to-end.
- [ ] **Audit log / activity history** — track who changed what and when across entities.

### Reporting & analytics
- [ ] **Advanced reporting** — custom date ranges, per-category drill-down, exportable Excel/CSV (currently PDF only).
- [ ] **Project budget vs actual** dashboard — variance tracking against budget.
- [ ] **Labour cost analytics** — wage rollups, attendance trends per worker.

### Operations
- [ ] **GPS / geolocation for machinery and site check-ins.**
- [ ] **Purchase order workflow** — PO → GRN → bill reconciliation (currently receipts auto-create bills without a PO step).
- [ ] **Inventory transfer between projects.**
- [ ] **Low-stock automatic reorder suggestions.**

### Integrations & platform
- [ ] **Accounting software integration** (e.g., Tally / Zoho Books export).
- [ ] **Multi-language / localization.**
- [ ] **Role-customizable permissions** (beyond the fixed 3-tier model).
- [ ] **Document collaboration / annotations on blueprints.**
- [ ] **Web/desktop build** (responsive layout exists; not yet released as a target).

> ⚠️ Note: This pending list is derived from gaps observed in the codebase rather than explicit `TODO` markers — confirm priorities with the product owner before scheduling.
