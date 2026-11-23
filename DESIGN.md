# Design System — G-TRAMS Mobile ("The Civic Ledger" Mobile Edition)

## Creative North Star
G-TRAMS Mobile brings formal Philippine municipal authority into a fast, crisp, thumb-friendly Android app designed for outdoor legibility by tricycle operators and TODA presidents in Gasan, Marinduque.

## Color Tokens

### Brand & Accent
| Token | Hex | Usage |
|---|---|---|
| `gasanMaroon` | `#9E2A2B` | Primary CTA buttons, hero crest headers, active tab landmark, light-mode focus rings. |
| `gasanMaroonDeep` | `#7A1B22` | Pressed/gradient header depth, dark velvet hero framing. |
| `gasanMaroonTint` | `#FDF2F4` | Soft subtle badges/pills on light surfaces. |
| `gasanGold` | `#D4AF37` | Accent hairlines, dark-mode primary highlights, seal trim rings, Digital ID borders. |
| `gasanGoldAccessible` | `#F5E6B3` | Small text & badges placed over `#9E2A2B` maroon (`>7:1` contrast). |

### Light Theme Neutrals (Warm Paper — Zero Cool Slate Drift)
| Token | Hex | Usage |
|---|---|---|
| `warmAlabaster` | `#F6F5F3` | App scaffold canvas background. |
| `purePaper` | `#FFFFFF` | Cards, bottom sheets, form fields, app bars. |
| `sandHairline` | `#E4E1DC` | Crisp `1px` borders around cards, inputs, and dividers. |
| `inkCharcoal` | `#1F1D1B` | Primary titles and body text (`>14:1` contrast). |
| `slateTaupe` | `#6B6761` | Secondary captions, field labels, inactive icons (`>=4.6:1`). |

### Dark Theme Neutrals (Warm Obsidian)
| Token | Hex | Usage |
|---|---|---|
| `obsidianEarth` | `#14110F` | Dark scaffold canvas. |
| `darkStone` | `#1C1917` | Dark cards, bottom sheets, nav bar surface. |
| `darkUmber` | `#2E2A27` | Crisp `1px` structural borders in dark mode. |
| `darkParchment` | `#F6F5F3` | Primary dark-mode copy. |
| `darkAsh` | `#A8A29E` | Secondary dark-mode metadata. |

### Semantic Status Bands (4 WCAG AA Bands)
- **Active / Verified:** `#15803D` (`#DCFCE7` light bg / `#14532D` dark bg)
- **In-Progress / Warning:** `#B45309` (`#FEF3C7` light bg / `#78350F` dark bg)
- **Danger / Revoked / Expired:** `#B91C1C` (`#FEE2E2` light bg / `#7F1D1D` dark bg)
- **Neutral / Archived:** `#4B5563` (`#F3F4F6` light bg / `#27272A` dark bg)

## Typography
- **Primary Sans:** `Manrope` — clean geometric-humanist civic clarity across Display (`28sp` w800), Headline (`22sp` w700), Title (`17sp` w600), Body (`14sp` w400/500), and Caption (`12sp`).
- **Tabular Monospace:** `JetBrains Mono` with `FontFeature.tabularFigures()` — **mandatory** for every MTOP number, Plate number, Official Receipt (`OR#`), fee amount (`PHP`), OTP box, body number, and expiry countdown.

## Mobile Layout & Component Rules
1. **The One-Accent Landmark Rule:** Keep Gasan Maroon for hero headers, active nav items, and the single primary action per screen. Never flood cards with colored fills or `border-l-4` side stripes.
2. **Flat Civic Elevation:** Use `1px` crisp hairline borders (`#E4E1DC` light / `#2E2A27` dark) instead of heavy drop shadows.
3. **Shapes:** `12px` radius on cards/dialogs, `10px` radius on primary buttons & form inputs, `20px` top radius on modal bottom sheets, pill (`999px`) on status badges.
4. **Touch & Outdoor Ergonomics:**
   - Minimum `48dp` height on all interactive buttons, form fields, and nav targets.
   - Support **3-tier Text Size scaling** (`Normal 1.0x`, `Large 1.15x`, `Extra Large 1.30x`) without causing horizontal text clipping (`Flexible` / `Expanded` / `overflow: TextOverflow.ellipsis`).
   - Full UI states required on every screen: loading skeleton/spinner, empty state, error retry card, and inline validation feedback.
5. **Splash & Auth Signature:**
   - **Splash Screen:** Warm Alabaster / Obsidian background, Gasan Municipal Seal (`gasan-logo.png`) framed with a delicate Gasan Gold ring, tracked `G-TRAMS` wordmark, municipal caption, and thin animated maroon/gold progress bar.
   - **Auth Screens:** Deep Heritage Maroon header crest blended softly over `tricycle-login.jpg` / `tricycle-register.jpg` transitioning into a rounded Warm Alabaster/Pure Paper form surface.
