# SiteOS Rebrand — Work Log & Status

**Date:** 2026-06-14
**Scope:** Rebrand the Flutter app from *Civil Pro / clivi_management* to **SiteOS** — design system, identity, bundle id, new Firebase + Supabase backends, new GitHub repo — per `siteos_brand_guide.md`, `siteos_design_system.html`, `siteos_marketing_copy.md`.

---

## Status at a glance

| # | Task | Status |
|---|------|--------|
| 1 | Apply SiteOS design system | ✅ Done |
| 2 | Rebrand app identity (names + literals) | ✅ Done |
| 3 | Change bundle/application id → `in.siteos.app` | ✅ Done |
| 4 | New Firebase project + apps + config | ✅ Done |
| 5 | New Supabase project + schema migration | ⏳ App repointed; schema **pending apply** (see below) |
| 6 | New private GitHub repo + push | ⛔ Blocked (commit ready, push blocked) |
| 7 | Feature gap analysis (existing vs vision) | 🔄 Running (background) |
| 8 | New-feature spec | ⏸ Waiting on your doc |

**Verification:** `flutter analyze` → *No issues found*. `flutter pub get` → OK with new package name `siteos`.

---

## 1. Design system ✅

Strategy: kept every public symbol name in the theme files and changed only values/fonts, so all 100+ screens recolored with **zero broken imports**.

| File | Change |
|------|--------|
| `lib/core/theme/app_colors.dart` | SiteOS palette — Brand Blue `#1B4FD8`, Precision Teal `#0891B2`, Site Amber `#F59E0B`, Navy `#0F172A`, slate neutrals, `#F8FAFC` page bg. Added `brandBlue/brandAmber/brandTeal/brandNavy` aliases. |
| `lib/core/theme/text_styles.dart` | Space Grotesk (display/headings), Inter (body/labels), JetBrains Mono (amounts). Added `monoFontFamily` + `mono` style; `price` now mono. |
| `lib/core/theme/app_theme.dart` | Space Grotesk titles, Inter UI labels; radii 8px buttons/inputs, 12px cards, 16px modals; white app bar; teal/amber accents. |
| `lib/core/theme/app_spacing.dart` | **New** — `AppSpacing` (8px grid), `AppRadius`, `AppElevation` tokens. |
| `lib/core/widgets/siteos_logo.dart` | **New** — `SiteOsLogo` widget: rounded Brand Blue square + white "S" + Site Amber dot, optional wordmark, `color`/`onDark`/`onBrand` variants. |
| `lib/main.dart` | Font preload now Space Grotesk + Inter + JetBrains Mono (was Poppins). |

---

## 2. Identity rebrand ✅

- **Dart package:** `clivi_management` → `siteos` (`pubspec.yaml` + 7 `package:` import files).
- **App class:** `CliviManagementApp` → `SiteOsApp`; `MaterialApp.title` → `SiteOS`.
- **Display name:** "Civil Pro" → **SiteOS** (Android `android:label`, iOS `CFBundleDisplayName` + `CFBundleName`).
- **`AppConstants.appName`** → `SiteOS`.
- **In-app branding:** splash, login lockup, and dashboard sidebar now render `SiteOsLogo` (splash also shows tagline *"Every site. Under control."*).
- **Web:** `web/index.html`, `web/manifest.json` (name/short_name/theme `#1B4FD8`), `web/privacy.html`, `privacy/index.html`, `support/index.html` rebranded; support email → `support@siteos.in`.
- **Docs:** README + FEATURES/USER_MANUAL/TECHNICAL_DOCUMENTATION*/STORE_*/SETUP_GUIDE/test README name-rebranded.

---

## 3. Bundle / application id ✅  →  `in.siteos.app`

- `android/app/build.gradle.kts` — `namespace` + `applicationId` = `in.siteos.app`.
- Kotlin moved `…/kotlin/com/clivimanagement/app/MainActivity.kt` → `…/kotlin/in/siteos/app/MainActivity.kt`; package is `` `in`.siteos.app `` (backtick-escaped — `in` is a Kotlin keyword; Java-generated R/BuildConfig are unaffected).
- iOS `project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER` ×6 (`in.siteos.app` + `in.siteos.app.RunnerTests`).
- macOS intentionally skipped (not a shipping target).

---

## 4. New Firebase project ✅

Created brand-new project — the client's `clivi-management` project is **untouched**.

| Item | Value |
|------|-------|
| Project ID | `siteos-app` |
| Project number / sender | `926018893261` |
| Storage bucket | `siteos-app.firebasestorage.app` |
| Android app | `1:926018893261:android:8c6b925a8b3f6bd6640084` (`in.siteos.app`) |
| iOS app | `1:926018893261:ios:fa10252a2586551a640084` (`in.siteos.app`) |

Config written: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`, `firebase.json` (API keys live in those files; not duplicated here).
Note: billing is **off** (Spark/free) — fine for Crashlytics + FCM. Hosting reduced to the single default `siteos-app` site (old `clivi-privacy`/`clivi-support` sites dropped; re-add if needed).

---

## 5. New Supabase project ⏳ (schema pending)

- **App repointed:** `assets/env` → `SUPABASE_URL=https://pennxpaodlpkfzzpiuwp.supabase.co` + new anon key.
- **Schema NOT yet applied** — the new project is empty. I cannot apply it via the MCP: this MCP token is authed only for the **"maega"** org and returns *"no permission"* for `pennxpaodlpkfzzpiuwp`. (MCP credentials are set in your Claude Code config; I can't change them.)
- **Deliverable ready:** `supabase/migrations/_CONSOLIDATED_SCHEMA.sql` — migrations **001→051 in order** (6,854 lines). Storage buckets (`avatars`/`blueprints`/`receipts`) are created by migrations 001 & 003; no pg_cron/extensions required.

**To finish (pick one):**
- **A — SQL Editor (fastest):** paste `_CONSOLIDATED_SCHEMA.sql` into the new project → **SQL Editor → Run**. Then enable Email auth and create the first super-admin (`supabase/migrations/SETUP_GUIDE.md`).
- **B — Re-auth MCP:** point the Supabase MCP at the account that owns `pennxpaodlpkfzzpiuwp` (a Personal Access Token from that account). Then I apply all 51 migrations + verify programmatically.

---

## 6. New GitHub repo ⛔ (push blocked)

- Client repo **`kalyan1421/Clivi-Management`** restored and **untouched** (an earlier rename was reverted).
- Local fresh-history commit **`b03bfde`** ("Initial SiteOS commit", 475 files) ready; `origin` set to `https://github.com/kalyan1421/SiteOs.git`.
- **Secrets excluded** from the commit via `.gitignore`: `assets/env`, `**/google-services.json`, `**/GoogleService-Info.plist` (a committed `assets/env.example` template was added).
- **Blocked because:** private push is disabled on the account ("repository is disabled"), and the safety system blocks force-pushing source to a *public* repo. **Need a working private destination** — fix the account's private-repo restriction (github.com → Settings → Billing), or provide another private repo URL.

> Old git history is preserved on `Clivi-Management` and recoverable locally via reflog.

---

## 7 & 8. Analysis & new features

- **Feature gap analysis** (existing modules vs. the SiteOS marketing vision: WhatsApp reports, Tally export, AI OCR/voice/chat, BOQ-vs-actual, client portal, snags) is running and will be delivered separately.
- **New-feature spec** is on hold pending your features doc.

---

## Key identifiers (quick reference)

| | Old (client — untouched) | New (SiteOS) |
|---|---|---|
| App name | Civil Pro / clivi_management | **SiteOS** / `siteos` |
| Bundle id | `com.clivimanagement.app` | `in.siteos.app` |
| Firebase | `clivi-management` (`1611595429`) | `siteos-app` (`926018893261`) |
| Supabase | `fhochkjwsmwuiiqqdupa` | `pennxpaodlpkfzzpiuwp` |
| GitHub | `kalyan1421/Clivi-Management` | `kalyan1421/SiteOs` (push pending) |

---

## What I need from you
1. **Supabase:** choose path A (run the consolidated SQL) or B (re-auth the MCP).
2. **GitHub:** a working **private** destination for the push.
3. **New features:** share the doc and I'll spec/architect it.
