# 📦 Civil Pro — Store Release Checklist

Status of everything needed to publish on **Google Play** (Android) and the **Apple App Store** (iOS).

- **App name:** Civil Pro
- **Bundle / Application ID:** `com.clivimanagement.app`
- **Version:** `1.0.0+1` (versionName `1.0.0`, versionCode/build `1`)
- **Backend:** Supabase (Postgres + RLS + Storage + Realtime)

---

## ✅ Done in code (this session)

| Item | Detail |
|------|--------|
| App ID fixed | `com.example.*` → `com.clivimanagement.app` (Android namespace + applicationId, iOS bundle id, Kotlin package, RunnerTests) |
| Release keystore | `android/upload-keystore.jks` generated; `android/key.properties` wired into `build.gradle.kts` (both gitignored) |
| Signing config | Release builds now use the upload keystore; falls back to debug only if `key.properties` is absent |
| SDK levels pinned | `compileSdk=35`, `targetSdk=35`, `minSdk=23` (Play requires API 35 for new apps) |
| Code shrinking | R8 minify + resource shrinking enabled with Flutter-safe `proguard-rules.pro` |
| Adaptive icon | Android adaptive icon generated (`mipmap-anydpi-v26`, white background) |
| iOS icon | 1024×1024 marketing icon flattened — **no alpha** (App Store requirement) |
| iOS encryption | `ITSAppUsesNonExemptEncryption=false` added to `Info.plist` (skips per-submission prompt) |
| Privacy policy | **LIVE → https://clivi-privacy.web.app** (separate Firebase site `clivi-privacy`, source in `privacy/index.html`) |
| Support page | **LIVE → https://clivi-support.web.app** (separate Firebase site `clivi-support`, source `support/index.html`) |
| Store copy | Drafted for Play + App Store → `STORE_LISTING_COPY.md` |
| Crashlytics | Firebase Crashlytics wired (Android + iOS apps registered, `firebase_options.dart`, error handlers in `main.dart`); release-only collection |
| Verified | `flutter build appbundle --release` succeeds (55.3MB w/ Firebase), signed with `CN=Clivi Management`; iOS `pod install` resolves Firebase pods (iOS 15) |

> ⚠️ **BACK UP YOUR KEYSTORE.** The password was printed in the terminal during generation.
> Store `android/upload-keystore.jks` **and** the password somewhere safe (password manager).
> If you lose either, you can **never** update the app on Play — you'd have to publish a new listing.

---

## 🔴 Must do before submitting (you)

### Accounts & hosting
- [ ] **Apple Developer Program** membership ($99/yr) — https://developer.apple.com/programs/
- [ ] **Google Play Console** account ($25 one-time) — https://play.google.com/console
- [x] **Privacy policy hosted** → https://clivi-privacy.web.app (separate Firebase site,
      does not touch the app website). To update it later: edit `privacy/index.html`,
      then `firebase deploy --only hosting:clivi-privacy`.
- [ ] Update the support email in `privacy/index.html` (currently `support@clivimanagement.app`)
      to a real inbox you control, **or** register that domain — then redeploy.

### Demo / review account (CRITICAL — app is login-gated)
- [ ] Create a working demo login (e.g. a `site_manager` with sample data).
- [ ] Apple: enter it under **App Review Information → Sign-In required → demo username/password.**
      Apple **auto-rejects** login-gated apps with no demo credentials.
- [ ] Play: add the same in **App content → App access** (declare login + provide creds).

---

## 🤖 Google Play — submission checklist

### Build
- [ ] `flutter build appbundle --release` → produces `build/app/outputs/bundle/release/app-release.aab`
- [ ] Enroll in **Play App Signing** (recommended) and upload the `.aab`.
- [ ] (Optional) Verify the upload-key SHA-1 if you later add Firebase/Google sign-in.

### Store listing assets
- [ ] App icon 512×512 (PNG, 32-bit)
- [ ] **Feature graphic** 1024×500 (required)
- [ ] Phone screenshots ×2–8 (min 320px; 16:9 or 9:16)
- [ ] (If supporting tablets) 7" and 10" tablet screenshots
- [ ] Short description (≤80 chars) + Full description (≤4000 chars)
- [ ] App category (e.g. *Business* / *Productivity*) + tags

### Policy / compliance
- [ ] **Data safety form** — declare: account info, photos/files, app activity;
      collected for app functionality; encrypted in transit; not sold.
- [ ] **Content rating** questionnaire (likely *Everyone*)
- [ ] **Target audience** (not directed to children)
- [ ] Privacy policy URL
- [ ] Permissions justification: `CAMERA`, `READ_MEDIA_IMAGES` (used for site photos/receipts)
- [ ] Declare no ads (or complete ads declaration)

---

## 🍎 Apple App Store — submission checklist

### Build
- [ ] In Xcode: set the **Team** for `Runner` (DEVELOPMENT_TEAM `AQLMTLP6PD` already set — confirm it's the right account) and signing for Release (distribution profile).
- [ ] Create the app record in **App Store Connect** with bundle id `com.clivimanagement.app`.
- [ ] `flutter build ipa --release` → upload via Xcode Organizer or `xcrun altool`/Transporter.

### Store listing assets
- [ ] App icon 1024×1024 (already in `Assets.xcassets`, opaque ✅)
- [ ] Screenshots: **iPhone 6.7"** (required) and **6.5"**; **iPad 12.9"** if you mark iPad support
- [ ] Name (≤30 chars), Subtitle (≤30), Promotional text, Description, Keywords (≤100)
- [ ] Support URL + Marketing URL
- [ ] Privacy policy URL

### Privacy / compliance
- [ ] **App Privacy "nutrition labels"** — declare: Contact Info (email/name),
      User Content (photos, files), Identifiers (account/user id); linked to identity;
      used for App Functionality; **not** used for tracking.
- [ ] Age rating questionnaire
- [ ] Export compliance: uses only standard HTTPS encryption → answer "No" to custom
      encryption (add `ITSAppUsesNonExemptEncryption=false` to `Info.plist` to skip the prompt — optional).
- [ ] Consider whether you support iPad; if not, set the app to iPhone-only in App Store Connect.

---

## 🟡 Recommended (not blocking)
- [x] Crash reporting — Firebase Crashlytics integrated.
- [ ] **iOS dSYM upload (optional):** for fully symbolicated *native* iOS crashes, add a Run Script
      build phase to the `Runner` target: `"${PODS_ROOT}/FirebaseCrashlytics/run"` with input files
      `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}`
      and `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`. Dart crashes are symbolicated without this.
- [ ] Verify crashes appear in the Firebase console (Crashlytics) after a test release install.
- [ ] Add a `flutter_native_splash` branded splash (currently default white).
- [x] No stray `print()` calls — code uses the shared `logger`.
- [ ] Test a real release build on a physical device for both platforms.
- [x] `ITSAppUsesNonExemptEncryption=false` set in `ios/Runner/Info.plist`.

---

## 🔧 Build commands (quick reference)
```bash
# Android release bundle (for Play)
flutter build appbundle --release

# iOS release archive (for App Store; run on macOS)
flutter build ipa --release

# Regenerate launcher icons after replacing assets/images/logo.png
dart run flutter_launcher_icons

# Host privacy policy via existing Firebase hosting
flutter build web && firebase deploy --only hosting
```
