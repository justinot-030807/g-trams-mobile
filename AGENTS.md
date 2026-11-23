# G-TRAMS Mobile Agent Instructions

> **Project:** **G-TRAMS Mobile** — Dedicated Flutter Android APK for **Tricycle Operators** and **TODA Presidents** of the Municipality of Gasan, Marinduque.
> **Full Specs:** See `PROJECT_CONTEXT.md`, `DESIGN.md`, and `docs/api-contract.md`.

## Strict Repository Isolation Rules (Read Carefully)

1. **Zero-Touch Web Repo Rule:** The main G-TRAMS web & backend repository lives at `C:\Users\Hp\GTRAMS`. **NEVER modify, delete, or create any file inside `C:\Users\Hp\GTRAMS`** from this mobile workspace. Treat `C:\Users\Hp\GTRAMS` strictly as an optional **read-only reference** only when the user explicitly asks to sync new backend API changes.
2. **Self-Contained Context First:** Always rely on `docs/api-contract.md`, `PROJECT_CONTEXT.md`, `DESIGN.md`, and `brain/` inside this repository before consulting external paths.
3. **Target Roles Only (Mobile Role Guard):**
   - This Android APK is strictly for **`operator`** and **`toda_president`** accounts.
   - Municipal staff roles (**OVM / LLSA I** internal DB enum `'bplo_staff'`, **`cashier`**, and **`system_admin`** / `'admin'`) MUST be rejected at login with an official Civic notice redirecting them to `https://g-trams-official.vercel.app`, and their token must be discarded immediately.
   - **Never write "BPLO"** in UI copy, labels, emails, or user-facing docs. The municipal licensing office is **Office of the Municipal Vice Mayor (OVM) — Local Legislative Staff Assistant I (LLSA I)**. Only reference `'bplo_staff'` in internal role-matching code for backend enum compatibility.
4. **Live Backend Connection:**
   - Production API: `https://g-trams-web2.onrender.com` (`/api/v1`)
   - Local Dev API: `http://<LAN-IP>:3000` (configured via `--dart-define=API_BASE_URL=...`)
   - Never route requests through legacy `workers.dev` URLs.

## UI & Architecture Guardrails

- **Design System:** Strictly follow `DESIGN.md` ("The Civic Ledger" Mobile Edition — Warm Alabaster `#F6F5F3`, Pure Paper `#FFFFFF`, Sand Hairline `#E4E1DC`, Gasan Heritage Maroon `#9E2A2B` / Deep `#7A1B22`, Gasan Gold `#D4AF37`, Warm Obsidian Dark `#14110F` / `#1C1917` / `#2E2A27`, `Manrope` + `JetBrains Mono` tabular numerals). Zero cool slate grays, zero generic AI gradients, zero `border-l-4` accent stripes.
- **Flutter Architecture:** Layered separation of concerns (`lib/core/`, `lib/data/`, `lib/features/<feature>/{view_models,views,widgets}`), Riverpod state management, GoRouter declarative routing, `48dp` minimum touch targets, EN/FIL localization, Light/Dark/System themes, and 3-tier Text Size scaling.
- **Web Preview Safety:** Guard Android-only plugins (`local_auth`, `google_mlkit_document_scanner`, `mobile_scanner`) behind `!kIsWeb` checks so `flutter run -d chrome` works smoothly alongside Android APK builds.
- **Verification Before Done:** Always run `flutter analyze` (`0` issues) and `flutter test` before reporting a phase or feature complete.

## Second Brain Memory (`brain/`)

- **Startup Rule:** Read `brain/00-index.md` and `brain/active-task.md` before starting any feature or refactor.
- **Conciseness Rule:** Keep all `brain/*.md` notes short and bulleted; never paste raw source code.
- **AI Attribution Rule:** Log updates in `brain/active-task.md` and `brain/audit-log.md` with `Agent (Model)` (write `<Agent> (model unspecified)` if exact model ID is not provided).
