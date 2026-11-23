# Technical & UI Decisions (Non-Negotiable)

- **Zero-Touch Parent Repo:** Never modify any file in `C:\Users\Hp\GTRAMS`. Keep all mobile docs, assets, code, and `.git` strictly inside `C:\Users\Hp\g-trams-mobile`.
- **Mobile Role Isolation:** Admit ONLY `operator` and `toda_president`. Block `'bplo_staff'` (OVM / LLSA I), `cashier`, and `system_admin` / `'admin'` at login with a Web Portal redirect notice and immediate token purge.
- **OVM / LLSA I Copy Rule:** Never use `"BPLO"` in any user-facing copy, tooltip, or doc; always use **Office of the Municipal Vice Mayor (OVM) — LLSA I**.
- **Civic Ledger Palette:** Warm Alabaster `#F6F5F3`, Pure Paper `#FFFFFF`, Sand Hairline `#E4E1DC`, Heritage Maroon `#9E2A2B` (`#7A1B22` deep), Gasan Gold `#D4AF37`, Obsidian Dark `#14110F` / `#1C1917` / `#2E2A27`. Fonts: `Manrope` + `JetBrains Mono` (`tabularFigures`). No cool slate drift, no generic AI neon gradients, no `border-l-4` stripes.
- **Idempotent Retries Only:** Retry only `GET`/`HEAD`/`OPTIONS` requests on Render cold-start (`502`/`503`/`504`/network timeouts); never auto-retry mutating `POST`/`PUT`/`DELETE` calls.
- **Web-Safe Plugin Guards:** Gate Android-only native plugins (`local_auth`, ML Kit, QR camera) with `!kIsWeb` so `flutter run -d chrome` works smoothly alongside Android builds.
