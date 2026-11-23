# G-TRAMS Mobile — Project Context

## 1. Name & Purpose
- **G-TRAMS Mobile** (*Gasan Tricycle Records and Application Management System — Operator & TODA Companion App*): Native Android APK built with Flutter for **Tricycle Operators** and **TODA Presidents** in the Municipality of Gasan, Marinduque.
- Shares 100% live records (MongoDB Atlas, Cloudinary `GTRAMS_Documents`, 3-Tier AI OCR, Socket.IO real-time messaging/notifications) with the G-TRAMS Express 5 backend while providing a faster, mobile-native UX separate from the web portal.
- **Excluded Roles:** OVM / LLSA I Licensing Staff (internal DB role `'bplo_staff'`), Municipal Cashier (`cashier`), and System Admin (`system_admin`) use the Web Portal (`https://g-trams-official.vercel.app`) exclusively.

## 2. Backend & Environment Endpoints
- **Production API Base URL:** `https://g-trams-web2.onrender.com`
- **Web Portal URL (Staff Redirect & Public QR Verify):** `https://g-trams-official.vercel.app`
- **Local Dev Backend URL:** `http://10.0.2.2:3000` (Android Emulator) or `http://<LAN-IP>:3000` (Physical Device)
- **API Prefix:** `/api/v1`
- **Default Google Web Client ID (used as Android `serverClientId`):** `371606618285-og7vq7cn9gb0kpacq171fhf1jclvlhgq.apps.googleusercontent.com`
- **Override at build/run time:**
  ```powershell
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
  flutter build apk --release --dart-define=API_BASE_URL=https://g-trams-web2.onrender.com
  ```

## 3. Tech Stack
- **SDK:** Flutter 3.38.7 (stable), Dart 3.10.7, Android Min SDK 24+ / Target SDK 35.
- **State & Routing:** `flutter_riverpod`, `go_router`.
- **Networking & Realtime:** `dio` (with Bearer JWT interceptor, `X-Server-Time` UTC+8 sync, idempotent `GET` Render cold-start retries), `socket_io_client` (v3, Socket.IO v4 compatible).
- **Storage & Security:** `flutter_secure_storage` (encrypted JWT & session metadata), `shared_preferences` (theme, locale, text scale, onboarding flag), `hive_flutter` (offline MTOP E-Copy, Operator ID card cache, and wizard drafts), `local_auth` (optional biometric unlock).
- **UI & Typography:** `google_fonts` (`Manrope` & `JetBrains Mono`), `pinput` (6-digit OTP boxes), `qr_flutter`, `flutter_native_splash`, `flutter_launcher_icons`.

## 4. Core LGU Business Rules (Mirroring G-TRAMS Backend)
- **LGU Pipeline Order (Payment Before Signing):** `Pending` (OVM / LLSA I Review) → `For Payment` (Municipal Cashier / Treasury) → `For Signing` (OVM / SB Endorsement) → `Ready for Pickup` (LLSA I Release) → `Active`.
- **Unit Allocation Cap:** Enforced dynamically from `/api/v1/settings` (`maxUnitsPerOperator`, default `2` units per Municipal Ordinance Section 4).
- **Jurisdiction Filtering:** 25 official Gasan Barangays → 3 Zones (`Central`, `North`, `South`) → 17 Accredited TODAs (`BATODA`, `POB TODA`, `GT TODA`, `LUG TODA`, `NBI TODA`, `BANGBANG IPIL TODA`, `TAB TODA`, `TIGUION TODA`, `MASIGA TODA`, `MAT TODA`, `PG TODA`, `4B TODA`, `DPAB TODA`, `ILAYA TODA`, `GASAN CENTRAL TODA`, `BAHI TODA`, plus `NON-TODA`).
- **TODA Roster Gate:** New operator sign-up verifies Legal Name + Accredited TODA + Assigned Body Number via `POST /api/v1/auth/verify-roster` before requesting OTP.
- **5-Step Application Wizard:** Step 1 Operator & TODA → Step 2 Vehicle Specs & OR/CR → Step 3 Driver's License & Barangay Clearance *(no TODA Endorsement upload)* → Step 4 Review & Cedula → Step 5 Summary & Submit.
- **Data Privacy (RA 10173):** Never display/request driver blood type, payment amounts, or document signatories from OCR scans.
- **Server-Authoritative Time (`Asia/Manila`):** Always prefer server `daysRemaining` / `expiryDate` and `X-Server-Time` response header over device clock.

## 5. Official UAT Tester Accounts (Shared DB, Default Password: `Password123!`)
- **Tricycle Operator 1 (`operator`):** `operator.tester@gtrams.com` / `09222222222`
- **Tricycle Operator 2 (`operator`):** `ian.operator@gtrams.com` / `09555555555`
- **TODA President (`toda_president`):** `todapres.tester@gtrams.com` / `09333333333`
- **Blocked Staff Test Accounts (Must Trigger Role Guard):**
  - OVM / LLSA I (`bplo_staff`): `llsa.tester@gtrams.com`
  - Municipal Cashier (`cashier`): `cashier.tester@gtrams.com`
  - System Admin (`system_admin`): `admin.tester@gtrams.com`

## 6. Commands
- **Analyze:** `flutter analyze`
- **Test:** `flutter test`
- **Web Preview (No Android SDK needed):** `flutter run -d chrome`
- **Release APK (Requires Android SDK or GitHub Actions):** `flutter build apk --release`
