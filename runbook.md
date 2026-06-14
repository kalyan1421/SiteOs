# SiteOS — Runbook

> Complete reference for running, deploying, and maintaining SiteOS.  
> Stack: Flutter 3.32 · Supabase (PostgreSQL) · Firebase (Crashlytics + Hosting) · GitHub Actions

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Local Flutter Setup](#2-local-flutter-setup)
3. [Environment Variables](#3-environment-variables)
4. [Supabase — Apply All Migrations](#4-supabase--apply-all-migrations)
5. [Edge Functions — Deploy](#5-edge-functions--deploy)
6. [Firebase — Setup & Hosting](#6-firebase--setup--hosting)
7. [GitHub Actions CI/CD](#7-github-actions-cicd)
8. [Running the App](#8-running-the-app)
9. [Feature Flags & Plans](#9-feature-flags--plans)
10. [Key Secrets Reference](#10-key-secrets-reference)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter | 3.32.x stable | `flutter upgrade` |
| Dart | 3.10.x | ships with Flutter |
| Node.js | 20+ | for Supabase CLI |
| Supabase CLI | latest | `brew install supabase/tap/supabase` |
| Firebase CLI | latest | `npm install -g firebase-tools` |
| GitHub CLI | latest | `brew install gh` |

```bash
# Verify
flutter --version
supabase --version
firebase --version
```

---

## 2. Local Flutter Setup

```bash
# 1. Clone the repo
git clone https://github.com/kalyan1421/SiteOs.git
cd SiteOs

# 2. Install dependencies
flutter pub get

# 3. Generate l10n (must run once, and after any ARB changes)
flutter gen-l10n

# 4. Run code generation (freezed models + riverpod)
dart run build_runner build --delete-conflicting-outputs

# 5. Verify no analyzer issues
flutter analyze
# Expected: "No issues found!"
```

---

## 3. Environment Variables

The app reads secrets from `assets/env` (dotenv format). This file is gitignored.

```bash
# Copy the example template
cp assets/env.example assets/env
```

Edit `assets/env`:

```dotenv
SUPABASE_URL=https://pennxpaodlpkfzzpiuwp.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> **Never commit `assets/env` to git.** It is in `.gitignore`.  
> The file is bundled into the app at build time — treat it like a `.env` file.

---

## 4. Supabase — Apply All Migrations

**Project:** `pennxpaodlpkfzzpiuwp` (SiteOS — new project, not the old clivi one)  
**Dashboard:** https://supabase.com/dashboard/project/pennxpaodlpkfzzpiuwp

### Option A — Supabase SQL Editor (recommended for first-time setup)

1. Open the SQL Editor: Dashboard → SQL Editor → New query
2. Apply in this exact order — paste each file and click **Run**:

#### Step 1 — Consolidated legacy schema (001→051)
```
supabase/migrations/_CONSOLIDATED_SCHEMA.sql
```
This is a single 6,854-line file containing migrations 001–051 in order.

#### Step 2 — SiteOS SaaS foundation (apply in number order)
| File | What it creates |
|---|---|
| `052_saas_foundation.sql` | `companies` table, plan columns, `plan_features`, `current_company_id()` RLS helper |
| `053_register_company_rpc.sql` | `register_company()` SECURITY DEFINER RPC (atomically creates company + links user) |
| `054_qa_qc.sql` | QA/QC checklist templates, project checklists, snags + `snags` storage bucket |
| `055_boq.sql` | BOQ headers + items, BOQ vs actual view |
| `056_ra_billing.sql` | Clients, GST config, RA bills, TDS/retention calculations |
| `057_whatsapp.sql` | WhatsApp config + send logs |
| `058_client_portal.sql` | Client portal read-only views (for `client` role) |
| `059_gps_attendance.sql` | GPS check-ins, geofence configs per project |
| `060_purchase_orders.sql` | Purchase indents + PO approval workflow |
| `061_rera.sql` | RERA quarterly reports |
| `062_subcontractor.sql` | Subcontractors, work orders, sub RA bills |
| `063_ai.sql` | AI chat message history |

### Option B — Supabase CLI (if you have a linked project)

```bash
# Link once
supabase link --project-ref pennxpaodlpkfzzpiuwp

# Push all pending migrations
supabase db push

# Or apply a specific file
supabase db execute --file supabase/migrations/052_saas_foundation.sql
```

### Verify migrations applied

```sql
-- Run in SQL Editor to confirm all tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Expected: `companies`, `plan_features`, `checklist_templates`, `boq_headers`, `ra_bills`, `subcontractors`, `work_orders`, `ai_chat_messages`, etc.

### Storage buckets to create manually

If buckets weren't created by migrations, create in Dashboard → Storage:

| Bucket | Public | Allowed MIME |
|---|---|---|
| `blueprints` | No | `application/pdf,image/*` |
| `site-photos` | No | `image/*` |
| `receipts` | No | `image/*,application/pdf` |
| `snags` | No | `image/*` |

---

## 5. Edge Functions — Deploy

**6 functions** live in `supabase/functions/`:

```
ai-invoice-ocr/
ai-daily-report/
ai-boq/
ai-chat/
whatsapp-send/
create-site-manager/
```

### One-time setup

```bash
# Install Deno (required for local testing)
brew install deno

# Link project
supabase link --project-ref pennxpaodlpkfzzpiuwp
```

### Set secrets (required before deploying AI + WhatsApp functions)

```bash
# Gemini (all AI functions)
supabase secrets set GEMINI_API_KEY=<your-key-from-aistudio.google.com>

# WhatsApp Cloud API (Meta)
supabase secrets set WHATSAPP_PHONE_NUMBER_ID=<your-phone-number-id>
supabase secrets set WHATSAPP_ACCESS_TOKEN=<your-permanent-token>
```

Get Gemini key free at: https://aistudio.google.com → Get API Key (1M tokens/day free)

### Deploy all functions

```bash
# Deploy each function
supabase functions deploy ai-invoice-ocr
supabase functions deploy ai-daily-report
supabase functions deploy ai-boq
supabase functions deploy ai-chat
supabase functions deploy whatsapp-send
supabase functions deploy create-site-manager
```

Or deploy all at once:
```bash
for fn in ai-invoice-ocr ai-daily-report ai-boq ai-chat whatsapp-send create-site-manager; do
  supabase functions deploy $fn
done
```

### Test a function locally

```bash
supabase functions serve ai-chat --env-file .env.local
curl -X POST http://localhost:54321/functions/v1/ai-chat \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"message":"How many workers are on Site A?"}'
```

---

## 6. Firebase — Setup & Hosting

**Project:** `siteos-app` (NEW — not the old clivi-management project)

### Install + login

```bash
npm install -g firebase-tools
firebase login
firebase use siteos-app
```

### First-time project setup (already done — for reference)

```bash
firebase init hosting
# Site ID: siteos-app
# Public dir: build/web
# Single-page app: yes
# GitHub actions: yes (configured in .github/workflows/firebase-deploy.yml)
```

### Build + deploy manually

```bash
# Build Flutter Web
flutter build web --release --web-renderer canvaskit

# Deploy to Firebase Hosting
firebase deploy --only hosting:siteos-app
```

### Download Firebase config files

If `google-services.json` or `GoogleService-Info.plist` get lost:

```bash
# Android
firebase apps:sdkconfig android 1:926018893261:android:... > android/app/google-services.json

# iOS (download from Firebase Console → Project settings → iOS app)
```

Both files are **gitignored** — never commit them.

### Crashlytics (already wired in `lib/main.dart`)

Crashlytics only reports in release builds. To test:
```bash
flutter build apk --release
# Install the APK, force a crash, check Firebase Crashlytics dashboard
```

---

## 7. GitHub Actions CI/CD

The workflow at [`.github/workflows/firebase-deploy.yml`](.github/workflows/firebase-deploy.yml) runs:

| Job | Trigger | What it does |
|---|---|---|
| `test` | Every push + PR | `flutter analyze` (fatal-infos), `flutter test` |
| `build-android` | Push to `main` | Builds release APK, uploads as artifact |
| `deploy-web` | Push to `main` | Builds Flutter Web → deploys to Firebase Hosting live channel |
| `preview` | Pull request | Builds Flutter Web → deploys to Firebase preview channel |

### Required GitHub Secrets

Go to: **GitHub repo → Settings → Secrets and variables → Actions**

| Secret | Value |
|---|---|
| `SUPABASE_URL` | `https://pennxpaodlpkfzzpiuwp.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anon JWT |
| `SUPABASE_URL_STAGING` | Same as prod (no staging yet) |
| `SUPABASE_ANON_KEY_STAGING` | Same as prod (no staging yet) |
| `FIREBASE_SERVICE_ACCOUNT_SITEOS` | Service account JSON from Firebase Console |
| `GOOGLE_SERVICES_JSON` | Full content of `android/app/google-services.json` |

### Get Firebase Service Account

1. Firebase Console → Project Settings → Service accounts
2. Click **Generate new private key** → downloads a JSON file
3. Copy the entire JSON content into the `FIREBASE_SERVICE_ACCOUNT_SITEOS` secret

---

## 8. Running the App

### iOS Simulator

```bash
open -a Simulator
flutter run -d iPhone
```

### Android Emulator

```bash
emulator -avd Pixel_7 &
flutter run -d emulator-5554
```

### Web (Chrome)

```bash
flutter run -d chrome --web-renderer html
# or CanvasKit for better rendering
flutter run -d chrome --web-renderer canvaskit
```

### With hot reload

```bash
flutter run
# Press r for hot reload, R for hot restart, q to quit
```

### Build release APK (Android)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. Feature Flags & Plans

SiteOS uses a plan-based feature guard system (see `lib/features/subscription/`).

### Plans

| Plan | Price | Trial |
|---|---|---|
| `trial` | Free | 14 days |
| `starter` | ₹1,999/mo | — |
| `professional` | ₹4,999/mo | — |
| `enterprise` | Custom | — |

### Setting a user's plan (for testing)

```sql
-- In Supabase SQL Editor
UPDATE companies SET plan = 'professional' WHERE id = '<company-uuid>';
```

### Checking which features are gated

See `lib/features/subscription/data/models/plan.dart`:

```dart
enum AppFeature {
  boqModule,        // professional+
  gstBilling,       // professional+
  aiFeatures,       // professional+
  whatsapp,         // starter+
  clientPortal,     // starter+
  gpsAttendance,    // starter+
}
```

### Bypass PlanGuard in dev

Set plan to `professional` in the DB (see above), or temporarily remove `PlanGuard` wrapper from the route during development.

---

## 10. Key Secrets Reference

| Secret | Where used | How to get |
|---|---|---|
| `SUPABASE_URL` | `assets/env` + CI | Supabase Dashboard → Settings → API |
| `SUPABASE_ANON_KEY` | `assets/env` + CI | Supabase Dashboard → Settings → API |
| `GEMINI_API_KEY` | Edge Function env only | https://aistudio.google.com → Get API Key |
| `WHATSAPP_PHONE_NUMBER_ID` | Edge Function env | Meta for Developers → WhatsApp → Phone numbers |
| `WHATSAPP_ACCESS_TOKEN` | Edge Function env | Meta for Developers → WhatsApp → System User token |
| `FIREBASE_SERVICE_ACCOUNT_SITEOS` | GitHub Actions | Firebase Console → Project Settings → Service accounts |
| `GOOGLE_SERVICES_JSON` | GitHub Actions | Firebase Console → Project Settings → Android app |
| Razorpay `key_id` + `secret` | AKS-66 (pending) | https://dashboard.razorpay.com |

> **Security rule:** AI keys (`GEMINI_API_KEY`) live ONLY in Supabase Edge Function secrets — never in the Flutter app bundle.

---

## 11. Troubleshooting

### `flutter analyze` shows errors

```bash
# Regenerate l10n after ARB changes
flutter gen-l10n

# Regenerate freezed/riverpod code
dart run build_runner build --delete-conflicting-outputs

# Re-run analyze
flutter analyze
```

### Supabase RLS blocking reads

```sql
-- Check the active user's company_id
SELECT id, company_id, role FROM user_profiles WHERE id = auth.uid();

-- Test the RLS helper
SELECT current_company_id();
```

### Firebase deploy fails in CI

- Check that `FIREBASE_SERVICE_ACCOUNT_SITEOS` secret has the full JSON (not just the file path)
- Verify `projectId: siteos-app` matches your actual Firebase project ID
- Run locally: `firebase deploy --only hosting --debug`

### App stuck on splash (no redirect after login)

The splash screen waits for `isInitialized` to be `true` in `authProvider`. If Supabase init fails (wrong URL/key in `assets/env`), it hangs. Check:
```bash
# Confirm env file exists
cat assets/env
```

### Migration fails with "relation already exists"

All migrations are written with `IF NOT EXISTS` / `ON CONFLICT DO NOTHING`. If one fails mid-way:
```sql
-- Check what ran
SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;
```

### Edge function 401 / JWT error

Ensure you're passing the Supabase session JWT, not the anon key, when calling from authenticated screens:
```dart
await supabase.functions.invoke('ai-chat',
  body: {'message': msg},
  headers: {'Authorization': 'Bearer ${supabase.auth.currentSession!.accessToken}'},
);
```

---

*Last updated: 2026-06-14 · SiteOS v1.0 · Kalyan Kumar Bedugam*
