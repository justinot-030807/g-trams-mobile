# G-TRAMS Mobile — Backend API & Socket.IO Contract

> **Source Backend:** Express 5 + Mongoose 9 + Socket.IO 4.8 (`https://g-trams-web2.onrender.com`)
> **Base Prefix:** `/api/v1`
> **Auth Header:** `Authorization: Bearer <jwt>` (`HS256`, `expiresIn: 1d`, `tokenVersion` checked on every request)
> **Server Time Headers:** Every response exposes `X-Server-Time` (ISO UTC) and `X-Server-Timezone: Asia/Manila`.
> **CORS:** Native mobile clients send no `Origin` header (`!origin` is explicitly allowed on both Express and Socket.IO).

---

## 1. System Settings & Health

| Method | Path | Auth | Purpose / Response Notes |
|---|---|---|---|
| `GET` | `/api/v1/health` | Public | `{ status: 'ok'\|'degraded', dbReady, indexesReady, message }` (`503` if degraded). |
| `GET` | `/api/v1/settings` | Public | `{ data: { maintenanceMode, fiscalYear, franchiseFee, penaltyRate, maxUnitsPerOperator, renewalReminderDays, validityNew, validityRenew, violationPolicy, announcements } }`. |
| `GET` | `/api/v1/settings/time` | Public | Authoritative server clock (`Asia/Manila`). |

---

## 2. Authentication, Registration & Profile (`/api/v1/auth`)

| Method | Path | Auth | Payload / Behavior |
|---|---|---|---|
| `POST` | `/api/v1/auth/login` | Public | Body: `{ contact, password }`. Returns `{ token, role, name, user, _id }`. Special statuses: `403 { accountDeactivated: true, contact, reason, appealStatus, hasLocalPassword, authProvider }`, `429 { retryAfterSeconds }`, `503` (maintenance mode). |
| `POST` | `/api/v1/auth/verify-roster` | Public | Body: `{ fullName, todaAssociation, bodyNumber }`. Returns `{ verified: bool, status, message, advisory }`. Gates registration against `TodaRoster` without leaking registered names. |
| `POST` | `/api/v1/auth/register` | Public | Body: `{ name, fullName, address, contact, password, confirmPassword, todaAssociation, bodyNumber, role: 'operator' }`. Sends 6-digit OTP via Brevo Email or TextBee SMS. `403` returns `{ advisory, message }` if roster check fails. |
| `POST` | `/api/v1/auth/verify-otp` | Public | Body: `{ contact, otp }`. Verifies account; returns `{ token, role, name, user }` (or success message requiring login). |
| `POST` | `/api/v1/auth/google` | Public | Body: `{ idToken, onboardingData? }`. Verifies `tokenData.aud === GOOGLE_CLIENT_ID`. If new user, returns `{ needsOnboarding: true, googleProfile: { email, name, picture, googleId, onboardingToken } }`. |
| `GET` | `/api/v1/auth/google-client-id` | Public | Returns `{ clientId }`. |
| `POST` | `/api/v1/auth/forgot-password` | Public | Body: `{ contact, useBackupContact?, preferredChannel?, recoveryTarget? }`. Returns `{ destination, resetChallengeToken, hasBackupContact, hasRecoveryEmail, hasRecoveryPhone, maskedRecoveryEmail, maskedRecoveryPhone, maskedPrimaryContact, message }`. |
| `POST` | `/api/v1/auth/reset-password` | Public | Body: `{ contact, otp, newPassword, resetChallengeToken? }`. Password requires `>=8` chars, uppercase, lowercase, number, and symbol. |
| `POST` | `/api/v1/auth/appeal` | Public | Body: `{ contact, password, message }` OR `{ contact, googleIdToken / googleAccessToken, message }`. Submits deactivation appeal. |
| `GET` | `/api/v1/auth/profile` | Bearer | Returns full authenticated user document (excluding password/OTP fields). |
| `PUT` | `/api/v1/auth/profile` | Bearer | Multipart (`profilePic`) or JSON (`name`, `contact`, `address`, `recoveryEmail`, `recoveryPhone`, `emergencyContact`, `language`, `currentPassword` / `recoveryOtp` / `googleReauthToken` when updating sensitive contacts). |
| `PUT` | `/api/v1/auth/change-password` | Bearer | Body: `{ oldPassword, newPassword }`. Increments `tokenVersion` (forces re-auth on other devices) and returns `{ message, token }`. |
| `POST` | `/api/v1/auth/request-recovery-otp` | Bearer | Requests OTP for adding/changing recovery email/phone. |
| `POST` | `/api/v1/auth/google-step-up` | Bearer | Step-up challenge for Google-only accounts changing recovery contacts. |
| `POST` | `/api/v1/auth/heartbeat` | Bearer | Updates `lastActive` presence timestamp. |
| `GET` | `/api/v1/auth/verify/:id` | Public | Public operator/franchise QR verification endpoint. |

### Mobile Role Guard Policy
Normalize `role` via `role.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_')`:
- **Allowed in Mobile APK:** `operator`, `toda_president`
- **Blocked (Redirect to Web Portal):** `bplo_staff` (OVM / LLSA I), `cashier`, `system_admin`, `admin`, `administrator`, or any other staff role.

---

## 3. Franchises (`/api/v1/franchises`)

*(Both `operator` and `toda_president` are authorized on all operator routes.)*

| Method | Path | Auth | Payload / Notes |
|---|---|---|---|
| `GET` | `/api/v1/franchises/my-franchises` | Bearer | Returns array of user's franchises (includes virtual `daysRemaining`, `expiryDate`, `paymentHistory`, `cancellationDetails`, `canFixIssues`, `canRefileRenewal`, `cancellationOutcome`). |
| `GET` | `/api/v1/franchises/:id` | Bearer | Detailed single franchise record. |
| `GET` | `/api/v1/franchises/check-unique` | Bearer | Query: `?field=plateNo|motorNo|chassisNo&value=...&excludeId=...`. Real-time duplicate check. |
| `GET` | `/api/v1/franchises/check-toda-member` | Public | Real-time TODA membership & jurisdiction check. |
| `POST` | `/api/v1/franchises/scan-document` | Bearer | Multipart: `file` (JPG/PNG/WEBP/PDF `<=15MB`), `docType` (`orcr`\|`cr`\|`or`\|`license`\|`licenseBack`\|`brgyClearance`\|`cedula`). Runs 3-Tier AI OCR (Gemini → Tesseract → OCR.space). Respects RA 10173 exclusions. |
| `POST` | `/api/v1/franchises` | Bearer | Multipart form data for 5-step application. File fields: `orCrDocument`, `crDocument`, `orDocument`, `license`, `licenseBack`, `brgyClearance`, `cedulaDoc`. |
| `PUT` | `/api/v1/franchises/:id` | Bearer | Multipart/JSON edit for rejected/reapply franchises (`authorizeFranchiseEdit`). |
| `PUT` | `/api/v1/franchises/:id/renew` | Bearer | Multipart fields: `orcrFile` / `orCrDocument` / `crDocument` / `orDocument`, `cedulaDoc`, `license`, `licenseBack`, `brgyClearance` + CTC & document metadata. |
| `PUT` | `/api/v1/franchises/:id/cancel` | Bearer | Operator withdraws unpaid pending application (`{ reason }`). |
| `PUT` | `/api/v1/franchises/:id/request-cancellation` | Bearer | Multipart: `reason`, `customReason`, `remarks`, plus either `letterText` (typed formal letter `>=30` chars) OR `cancellationLetter` file upload (`<=10MB`). |
| `GET` | `/api/v1/franchises/:id/download-original` | Bearer | Downloads official MTOP / Application Form document. |
| `POST` | `/api/v1/franchises/download-original-preview` | Bearer | Generates official form preview payload. |

### 12 Franchise Lifecycle States
- **In-Progress (Amber):** `Pending`, `Under Review`, `For Inspection`, `For Payment`, `For Signing`, `Ready for Pickup`, `Pending Cancellation`
- **Active (Green):** `Active`, `Active - Under Warning`
- **Danger (Red):** `Expired`, `Suspended`, `Revoked`
- **Neutral (Gray):** `Cancelled`, `Archived`

---

## 4. TODA Governance (`/api/v1/toda`) — TODA President Only

| Method | Path | Auth | Payload / Notes |
|---|---|---|---|
| `GET` | `/api/v1/toda/my-members` | Bearer (`toda_president`) | Returns `{ todaName, stats: { totalMembers, totalUnits, activeUnits, pendingUnits, expiredUnits }, members: [...] }`. |
| `GET` | `/api/v1/toda/next-body-number` | Bearer (`toda_president`) | Auto-generates next collision-free body number for the president's TODA. |
| `POST` | `/api/v1/toda/members/individual` | Bearer (`toda_president`) | Adds single accredited member (`operatorName`, `bodyNumber`, `plateNo?`, `contact?`, `remarks?`). |
| `POST` | `/api/v1/toda/scan-roster` | Bearer (`toda_president`) | Multipart `file` (JPG/PNG/PDF/XLSX/CSV `<=15MB`). Returns `{ success, extractedMembers, extractedCount, todaAssociation, ocrNotes }`. |
| `POST` | `/api/v1/toda/upload` | Bearer (`toda_president`) | Multipart `file` + JSON string `extractedMembers` + `ocrNotes`. Submits roster to OVM / LLSA I (`422` if 0 valid members). |
| `GET` | `/api/v1/toda/my-submissions` | Bearer (`toda_president`) | Historical roster submissions & approval statuses. |
| `GET` | `/api/v1/toda/removal-requests` | Bearer (`toda_president`) | Returns member disaffiliation requests for the president's TODA. |
| `POST` | `/api/v1/toda/removal-requests` | Bearer (`toda_president`) | Body: `{ memberId, reason, details, targetRosterId? }`. Valid reasons match `REMOVAL_REASONS`. |

---

## 5. Violations, Support Chat, Notifications & Tickets

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/api/v1/violations/history/:franchiseId` | Bearer | Operator/TODA President violation & progressive sanction history for a franchise. |
| `GET` | `/api/v1/chat/threads` | Bearer | Returns operator's support thread + Official LGU Announcements broadcast thread with `unreadCount`. |
| `GET` | `/api/v1/chat/unread-count` | Bearer | `{ unreadCount }`. |
| `GET` | `/api/v1/chat/messages/:threadId` | Bearer | Cursor-paginated messages (`?before=<id>&limit=100`). |
| `POST` | `/api/v1/chat/messages` | Bearer | Body: `{ threadId?, message }`. Triggers automated Tagalog FAQ replies & live socket push. |
| `PUT` | `/api/v1/chat/messages/:threadId/read` | Bearer | Marks thread messages and matching chat notifications as read. |
| `GET` | `/api/v1/notifications` | Bearer | Latest 50 notifications populated with `relatedFranchise`. |
| `GET` | `/api/v1/notifications/unread-count` | Bearer | `{ count }`. |
| `PUT` | `/api/v1/notifications/read-all` | Bearer | Marks all notifications read. |
| `PUT` | `/api/v1/notifications/:id/read` | Bearer | Marks one notification read. |
| `DELETE` | `/api/v1/notifications/:id` | Bearer | Deletes one notification. |
| `DELETE` | `/api/v1/notifications/clear-all` | Bearer | Clears all notifications. |
| `POST` | `/api/v1/tickets` | Bearer | Creates IT/Support ticket (`subject`, `contactNumber`, `message`). |
| `GET` | `/api/v1/tickets/my-tickets` | Bearer | Lists operator's submitted support tickets. |

---

## 6. Socket.IO Real-Time Protocol

- **URL:** Same origin as API (`https://g-trams-web2.onrender.com`), WebSocket transport.
- **Handshake Auth:** `auth: { 'token': '<jwt>' }`
- **Server-to-Client Events:**
  - `chat_message` — New live chat or broadcast announcement message.
  - `chat_typing` — `{ threadId, userId }` staff typing indicator.
  - `chat_read` — `{ threadId }` cross-device read sync.
  - `notification` — New real-time notification payload.
  - `notification_read`, `notification_deleted`, `notifications_marked_read`, `notifications_read_all` — Notification state sync.
  - `session_revoked` — `{ reason }` emitted when `tokenVersion` changes, password is updated, or account is deactivated; client MUST disconnect socket, clear secure storage, and route to `/login`.
- **Client-to-Server Events:**
  - `chat_typing` — `{ threadId, recipientId }` (rate-limited to 15 events / 5s).
