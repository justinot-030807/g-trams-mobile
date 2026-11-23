# G-TRAMS Mobile (Android APK)

Dedicated Flutter mobile companion app for **Tricycle Operators** and **TODA Presidents** of the **Municipality of Gasan, Marinduque** ("The Civic Ledger" Mobile Edition).

- **Web Portal (OVM / LLSA I, Municipal Cashier, System Admin):** `https://g-trams-official.vercel.app`
- **Live Shared API Backend:** `https://g-trams-web2.onrender.com/api/v1`
- **Android Application ID:** `ph.gov.gasan.gtrams.gtrams_mobile`

## Feature Complete (Phases 1–6)
- **Auth & Role Guard:** Login, 3-Step Registration with Live TODA Roster Gate & 6-Digit OTP, Google Sign-In, Forgot/Reset Password, Deactivated Account Appeal, Optional Biometric Unlock, and strict Mobile Role Guard blocking municipal staff roles.
- **Operator Garage & Offline Wallet:** Live fleet quota bar, 5-stage Payment-Before-Signing LGU stepper, `Asia/Manila` countdowns, Hive-cached Offline 3D-Flip Digital Operator ID + QR (`verify/:id`), Watermarked MTOP E-Copy & `OR#` E-Receipt, Violations & 3-Tier Sanctions History, Withdraw Application, and Voluntary Cancellation.
- **5-Step Apply, Fix-Reapply & Renewal Wizard:** Android ML Kit Smart Document Scanner (`!kIsWeb` guarded), 3-Tier AI OCR Auto-Fill (RA 10173 compliant), live Plate/Motor/Chassis duplicate & TODA jurisdiction checks, and Hive offline draft auto-save.
- **TODA President Governance Hub:** Live Member Directory & 4 KPIs, Individual Add + Auto-Next Body#, AI OCR Roster Scanner/Editor & OVM Upload, 6-reason Disaffiliation Requests, and Built-in Web-Safe QR Verifier (`mobile_scanner` on Android + universal URL/MTOP#/Plate# lookup).
- **Real-Time Updates & Settings Hub:** Socket.IO v4 Live Support Chat (with Tagalog FAQ guides, typing indicator & `session_revoked` protection), Official OVM Broadcast & Portal Advisories, Real-Time Notifications Center, Profile/Avatar Edit, OTP Account Recovery, Change Password with JWT/Socket rotation, Operator Document Vault, Helpdesk Tickets & Gasan LGU Hotlines.
- **Release Hardening:** Production keystore signing (`android/key.properties` or GitHub Actions secrets), R8 shrinking + ProGuard rules, HTTPS-only release manifest, EN/FIL localization, Light/Dark themes, and 3-tier Outdoor Text Size scaling.

## Quick Start

### 1. Install Dependencies
```powershell
flutter pub get
```

### 2. Run Preview in Chrome (No Android SDK Required)
```powershell
# Against live Render backend
flutter run -d chrome

# Against local G-TRAMS backend (running on port 3000)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

### 3. Run Static Analysis, Tests & Web Build
```powershell
flutter analyze
flutter test
flutter build web --no-pub --no-wasm-dry-run
```

### 4. Build Signed Release APK
- **Cloud Build (Zero local Android SDK needed):** Configure the 4 keystore secrets documented in `docs/release-signing-and-uat.md` and push to `main` or tag `v1.0.0` to trigger `.github/workflows/build-android-apk.yml` — produces Universal + Split-per-ABI `.apk` builds and `SHA256SUMS.txt`.
- **Local Build (with Android SDK & JDK 17):**
  ```powershell
  flutter build apk --release --dart-define=API_BASE_URL=https://g-trams-web2.onrender.com
  ```

## Project Documentation
- `AGENTS.md` — Mobile agent & isolation rules.
- `PROJECT_CONTEXT.md` — Stack, roles, endpoints, and UAT accounts.
- `DESIGN.md` — "The Civic Ledger" Mobile UI specification.
- `docs/api-contract.md` — Complete backend REST & Socket.IO reference.
- `docs/release-signing-and-uat.md` — Keystore signing, Google OAuth SHA-1 setup, CI/CD release guide & E2E UAT QA sign-off matrix.
- `brain/` — Independent mobile Second Brain tracking phases and audit logs.
