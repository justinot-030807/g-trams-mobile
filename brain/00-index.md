# G-TRAMS Mobile Second Brain Index

- **Project:** G-TRAMS Mobile — Flutter Android APK exclusively for **Tricycle Operators** and **TODA Presidents** (Municipality of Gasan, Marinduque).
- **Repo Isolation:** Standalone sibling repo (`C:\Users\Hp\g-trams-mobile`). Zero edits to `C:\Users\Hp\GTRAMS`.
- **Shared Production Backend:** `https://g-trams-web2.onrender.com/api/v1` · Web Portal: `https://g-trams-official.vercel.app`.
- **Current Stage:** ALL PHASES (1–6) COMPLETE — Release Ready (`v1.0.0`). Android Release Signing (`android/key.properties` + GitHub Actions keystore secrets), R8 shrinking & ProGuard keep rules, HTTPS-only release manifest, Universal + Split-per-ABI CI APK pipeline with `SHA256SUMS.txt`, Full E2E UAT QA Suite (`49/49` passing), and Release/UAT Guide (`docs/release-signing-and-uat.md`).

## Knowledge Map
- [[architecture]] — Flutter layered architecture, packages, core modules, and feature layout.
- [[decisions]] — Non-negotiable isolation rules, mobile role guard, LGU pipeline & Civic Ledger UI tokens.
- [[active-task]] — Active roadmap phase, progress log, and next milestone.
- [[audit-log]] — Verification runs, analyzer/test baselines, and defect history.

## Reference Docs
- `AGENTS.md` · `PROJECT_CONTEXT.md` · `DESIGN.md` · `docs/api-contract.md` · `docs/release-signing-and-uat.md` · `README.md`.
