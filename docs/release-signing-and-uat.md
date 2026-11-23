# G-TRAMS Mobile — Release Signing, Distribution & Full E2E UAT QA Guide

> **Application ID:** `ph.gov.gasan.gtrams.gtrams_mobile`  
> **Target Audience:** Tricycle Operators & TODA Presidents — Municipality of Gasan, Marinduque  
> **Production Backend:** `https://g-trams-web2.onrender.com/api/v1`  
> **Web Portal (OVM / LLSA I, Cashier, System Admin):** `https://g-trams-official.vercel.app`

---

## 1. Android Production Keystore & Release Signing Setup

Production Android APKs require a private upload keystore (`upload-keystore.jks`). **Never commit `.jks`, `.keystore`, or `android/key.properties` to Git** (already excluded via `.gitignore`).

### Step A — Generate the Official Municipal Upload Keystore (JDK 17 `keytool`)
```powershell
keytool -genkeypair -v `
  -keystore android/upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias gtrams-upload `
  -dname "CN=Municipality of Gasan OVM-LLSA I, OU=G-TRAMS Mobile, O=LGU Gasan Marinduque, L=Gasan, ST=Marinduque, C=PH"
```

### Step B — Extract SHA-1 & SHA-256 Fingerprints (Required for Android Google Sign-In)
```powershell
keytool -list -v -keystore android/upload-keystore.jks -alias gtrams-upload
```
1. Copy the **SHA-1** fingerprint into **Google Cloud Console → APIs & Services → Credentials** under an Android OAuth 2.0 Client ID for package `ph.gov.gasan.gtrams.gtrams_mobile`.
2. Keep the Web OAuth Client ID (`GOOGLE_CLIENT_ID` configured in `AppConfig.defaultGoogleClientId`) linked in the same Google Cloud project so `google_sign_in` returns valid `idToken`s verified by `POST /api/v1/auth/google`.

### Step C — Configure Local Signing OR GitHub Actions Cloud Signing

#### Option 1 — GitHub Actions Cloud Release APK (Recommended — Zero Local Android SDK Needed)
1. Encode the keystore to Base64:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("android/upload-keystore.jks")) | Set-Clipboard
   ```
2. Add these 4 Repository Secrets in **GitHub → Settings → Secrets and variables → Actions**:
   - `ANDROID_KEYSTORE_BASE64` — Base64 output from step 1
   - `ANDROID_KEYSTORE_PASSWORD` — Keystore password
   - `ANDROID_KEY_ALIAS` — `gtrams-upload`
   - `ANDROID_KEY_PASSWORD` — Key password
3. Push to `main` or tag a release (`git tag v1.0.0 && git push origin v1.0.0`):
   - Workflow `.github/workflows/build-android-apk.yml` runs `flutter analyze`, `flutter test`, `flutter build web`, OVM naming check, signs the APK with R8 shrinking enabled, and publishes:
     - `gtrams-mobile-universal-release.apk` (works on all Android 7.0+ / API 24+ devices)
     - `gtrams-mobile-arm64-v8a-release.apk` (compact APK for modern 64-bit phones)
     - `gtrams-mobile-armeabi-v7a-release.apk` (legacy 32-bit Android phones)
     - `SHA256SUMS.txt` (cryptographic integrity manifest)

#### Option 2 — Local Signed Build (Requires Android SDK + JDK 17)
1. Copy `android/key.properties.example` to `android/key.properties` and fill in your passwords.
2. Run:
   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=https://g-trams-web2.onrender.com
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 2. Android Security & Hardening Checklist (Verified in Repo)

| Control | Implementation | Status |
|---|---|---|
| Release HTTPS-Only Traffic | `android:usesCleartextTraffic="false"` in `src/main/AndroidManifest.xml` (cleartext allowed only in `src/debug/AndroidManifest.xml`) | Verified |
| Encrypted Storage Integrity | `android:allowBackup="false"` & `android:fullBackupContent="false"` protects `flutter_secure_storage` keys | Verified |
| R8 Code & Resource Shrinking | `isMinifyEnabled = true`, `isShrinkResources = true` + `android/app/proguard-rules.pro` keeping ML Kit, CameraX/Mobile Scanner, Tink, Biometrics & Google Sign-In | Verified |
| Biometric Hardware Support | `MainActivity : FlutterFragmentActivity()` + `USE_BIOMETRIC` permission | Verified |
| Camera Optionality | `CAMERA` permission + `android.hardware.camera` (`required="false"`) | Verified |
| OVM / LLSA I Copy Policy | Zero user-facing legacy office acronyms across `lib/features/` and `lib/shared/` | Verified |
| Parent Repo Isolation | Zero modifications inside `C:\Users\Hp\GTRAMS` | Verified |

---

## 3. End-to-End UAT QA Sign-Off Matrix (Shared Live DB)

> Default UAT Password across seeded accounts: `Password123!`

| # | Scenario | Account / Role | Expected Verified Result |
|---|---|---|---|
| 1 | **Role Guard (OVM Staff)** | `llsa.tester@gtrams.com` (`bplo_staff`) | Blocked at login with Civic dialog reading *"OVM / LLSA I Licensing Officer"* (never legacy acronym); token discarded; web portal redirect link works. |
| 2 | **Role Guard (Cashier)** | `cashier.tester@gtrams.com` (`cashier`) | Blocked at login with Civic dialog reading *"Municipal Cashier / Treasury"*; token discarded. |
| 3 | **Role Guard (SysAdmin)** | `admin.tester@gtrams.com` (`system_admin`) | Blocked at login with Civic dialog reading *"System Administrator"*; token discarded. |
| 4 | **Operator Login & Garage** | `operator.tester@gtrams.com` (`operator`) | 4-tab shell (`Home`, `Apply`, `Updates`, `Settings`); Quota bar `activeCount / maxUnitsPerOperator`; 5-stage Payment-Before-Signing stepper; `Asia/Manila` countdown. |
| 5 | **Offline Digital Wallet** | `operator.tester@gtrams.com` (Airplane Mode) | AppBar badge opens cached 3D-Flip Digital Operator ID + `https://g-trams-official.vercel.app/verify/:id` QR + Watermarked MTOP E-Copy & `OR#` E-Receipt with "Last synced" timestamp. |
| 6 | **Violations & Cancellation** | `operator.tester@gtrams.com` | Unit Violations sheet shows 3-tier progressive policy; unpaid Pending allows Withdraw; Active/Expired opens Hon. Lidany A. Lao-Baldo Voluntary Cancellation letter / file upload. |
| 7 | **5-Step Apply + OCR + Draft** | `ian.operator@gtrams.com` (`operator`) | Smart Scan / File upload triggers 3-Tier AI OCR; RA 10173 fields excluded; zero TODA Endorsement upload; live unique Plate/Motor/Chassis checks; Hive offline draft restores after restart. |
| 8 | **TODA Governance Hub** | `todapres.tester@gtrams.com` (`toda_president`) | 5-tab shell (`Home`, `TODA`, `Apply`, `Updates`, `Settings`); 4 KPI cards; Individual Member Add with Auto-Next Body#; AI OCR Roster Editor; 6-reason Disaffiliation Request; Built-in QR Camera & URL/Plate Verifier. |
| 9 | **Live Chat, Advisories & Alerts** | `operator.tester@gtrams.com` | Socket.IO `LIVE` pill; Tagalog FAQ chip returns automated guide; real-time notification increments AppBar bell & Updates badge; `session_revoked` logs out to `/login` with security banner. |
| 10 | **Settings, Vault & Helpdesk** | `operator.tester@gtrams.com` | Edit Profile & Avatar saves; OTP Recovery sends code; Change Password rotates JWT & reconnects Socket.IO; Document Vault zooms images & launches PDFs; Helpdesk Ticket submits `{ subject, contactNumber, message }`. |
| 11 | **Accessibility & Localization** | All Roles (`360px` screen) | Light & Dark modes, English & Filipino (`EN` / `FIL`), and Extra Large (`1.26x`) text scaling render with zero RenderFlex overflow. |
