# 04 — API and dashboard

The dashboard is a separate PHP/MySQL repo (`percipere_web`, folder `percipere_dashboard`),
served by XAMPP on the team's PC (checkout under `C:\xampp\htdocs\website\percipere_web\`).
**Its own `docs/api-contract.md` is the master API reference**; this file and the app's
`docs/api-contract.md` describe what the app uses. Dashboard internals are out of scope here.

## Base address
- Build flag `API_BASE_URL` = the dashboard folder URL, e.g.
  `http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard`. REST base = `{API_BASE_URL}/api/v1/`.
- Without it the app uses `https://percipere-admin.invalid` (`Env.noServer`): accounts stay on
  the phone, the Library has no admin books, reports stay pending.
- Developer builds (`PERCIPERE_DEV=true`) can change the address at runtime: Settings →
  "Server address (developer)" (`lib/core/network/server_address.dart`,
  `lib/features/settings/server_address_dialog.dart`).
- Requirement (as of 2026-10-13, per `CLAUDE.md`): the app needs the dashboard branch
  **`fix/webapp-api`** (REST routes). It was **not merged** then; current state **unverified**.
- HTTP client: `apiDio()` in `lib/core/network/api_dio.dart` (timeouts + `CleartextGuard`).

## Errors
Success = the plain JSON resource. Failure = `{"error": {"code", "message", "fields"?, "retry_after"?}}`
with an HTTP status. The app chooses its own spoken words from `error.code`.

## Accounts — `lib/core/auth/account_api.dart` (`HttpAccountApi`), `account_service.dart`
| Method + path | Body | Reply |
|---|---|---|
| `POST auth/register` | `full_name`, `email`, `password` | created; a 6-digit code is emailed |
| `POST auth/verify` | `email`, `code`, `device` | `{token, user}` |
| `POST auth/resend` | `email` | new code emailed |
| `POST auth/login` | `email`, `password`, `device` | `{token, user}` |
| `POST auth/logout` | — (Bearer token) | — |
| `GET auth/me` | — (Bearer token) | `{user}` (status check) |
| `POST auth/password-reset/request` | `email` | code emailed |
| `POST auth/password-reset` | `email`, `code`, `password`, `device` | `{token, user}` |
`user` = `{id, full_name, email, status}`. Error codes the app knows: `invalid_credentials`,
`verify_email`, `pending_approval`, `account_suspended`, `email_taken`, `invalid_code`,
`too_many_attempts` (+ `retry_after`), `unauthorized`, `email_unavailable`, `validation_failed`.

**Flow** (decision log 2026-10-10 (3)):
- Register → emailed code → `VerifyEmailScreen` (code dictated or typed) → token.
- Login → token stored in secure storage as `api.token.<localUserId>` (never in SQLite). Each
  server account has one local account (`users.server_id`) holding settings and Library; its
  password hash is refreshed at each server login so **offline login** works for accounts
  already used on the tablet.
- Phone-only account logging in with the right password → registered on the server, then code.
- Unverified → new code sent. Suspended / waiting for approval → reason spoken.
- `SessionGuard` (`lib/core/auth/session_guard.dart`) calls `auth/me` at start, after login and
  on resume: suspended → logged out; invalid token → token forgotten.
- Wrong passwords: phone lockout (30 s, doubling, max 1 h) still counts; server 429 uses
  `retry_after`.
- `USE_ACCOUNT_SERVER=false` keeps accounts on the phone only.

## Books (Aklatan) — `lib/core/library/http_book_repository.dart`
Public, no sign-in.
| Method + path | Use |
|---|---|
| `GET books?page=&per_page=50&updated_since=` | catalog, all pages until `total` |
| `GET books/{id}` | before download: still there? size and SHA-256 |
| `GET books/{id}/file` | PDF or EPUB (written to `<file>.part`, size + SHA-256 checked, then renamed) |
| `GET books/{id}/cover` | cover image; 404 = none |
Book fields: `id`, `title`, `author`, `description`, `category {id,name}`,
`language {id,name,code}`, `format` (`pdf`/`epub`), `file_size`, `checksum` (`sha256:<hex>`),
`version`, `cover_url`, `file_url`, `created_at`, `updated_at`. Higher `version` → update offer
(position kept); a book switched off disappears → shown as removed, progress kept. Books are
maintained in the dashboard and **must be public domain or licensed**. As of 2026-10-13 the
dashboard database had **no books yet** (unverified now).

## Reports — `lib/core/report/issue_report_api.dart`, `issue_report_sync.dart`
- `POST reports` with `ticket_no` (`PRC-YYYYMMDD-XXXX`), `type`/`module`/`severity` each as
  `{code, label}` (severity `null` unless a bug), `description` (10–1000 chars), `email` or null,
  `reporter {kind: account|guest, display_name: null}`, `app_version`, `os_version`,
  `device_model`, `source_screen`, `created_at`; optional `Authorization: Bearer <token>`.
  Reply `201 {id, ticket_no, status:"open", linked}`; the same ticket again → `200`, nothing new
  (safe retry). 4xx (not 429) = refused; 429/5xx/offline = pending, retried later.
- `GET reports/{ticket_no}` → `{ticket_no, status, updated_at}`, status
  `open|in_progress|resolved|closed` → shown as Natanggap / Ginagawa / Naayos na / Sarado,
  stored in `issue_reports.server_status`.
- Codes: type `bug|feature|feedback`; module `ocr|camera|voice_commands|accounts|text_to_speech|gestures|library|maglarawan|percy|other`;
  severity `low|medium|high|critical`.

## Offline voice models — `lib/core/offline_voice/model_installer.dart`
- Order: `GET {base}/api/v1/models` → `GET {base}/models/manifest.json` → built-in list
  (`OfflineModelCatalog.builtIn`) pointing at GitHub release `voice-models-v1` of
  `grunclerozz/percipere_app`.
- Manifest `{"models":[{name, version, size, sha256, url, fallback_url?, installed_size?}]}`;
  relative `url` is resolved against the base. Template: `tool/voice_models/manifest.json`.
- Download: HTTP `Range` resume into `.downloads/*.part`, size + SHA-256 check, free-space check,
  4 tries alternating server/GitHub, resumes when the connection returns; only newer versions
  replace installed ones.
- **Not done yet:** the archives are not uploaded to the dashboard `models/` folder or GitHub;
  the `GET /api/v1/models` route does not exist in the dashboard (the static file is enough).

## Planned / mocked
- `POST /api/describe-image` (multipart: `image`, `language`, `user_id` or `guest`) →
  `{description, has_text}`; the dashboard would call Gemini. App side uses
  `MockImageDescriptionRepository` while `USE_MOCK_API` is true (default). **The app never calls
  Gemini directly.**
- Library sync (`PUT /api/library/progress|favorites|collections`, `GET /api/library?since=`) —
  Phase 7, `MockLibrarySyncRepository`. Own documents never sync.
- Health check used in testing: `GET {base}/api/v1/health` (`docs/testing/first-tablet-test.md`).

## Network security (cleartext)
- Plain `http://` only to the host of `API_BASE_URL` (when it is http) and hosts in
  `API_CLEARTEXT_HOSTS`. `android/app/build.gradle.kts` generates
  `res/xml/network_security_config.xml` per build; Dart enforces the same rule in
  `CleartextGuard` (`lib/core/network/api_dio.dart`, `Env.allowsCleartext`) because Dart's HTTP
  client ignores Android's config. `https` is never blocked. A public server must use https.

## How the tablet reaches the PC (from `docs/testing/first-tablet-test.md`)
1. PC and tablet on the **same Wi-Fi**; start Apache and MySQL in XAMPP (the user does this).
2. `ipconfig` on the PC → IPv4 address of the Wi-Fi adapter (`<PC_LAN_IP>`); it can change after
   a router restart (then rebuild or use the developer server-address setting).
3. In the tablet's browser open `http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard/api/v1/health`
   before installing the app.
4. Timeout → Windows Firewall blocks Apache or the network profile is Public: allow
   `C:\xampp\apache\bin\httpd.exe` on TCP 80 for the Private profile and set the Wi-Fi to Private.
   404 → old dashboard without REST routes (needs `api/v1/index.php`, `.htaccess`, `mod_rewrite`).
5. Build the APK with that `API_BASE_URL`.

**Hosting online is planned** (a public https server); nothing is set up yet (unverified details).
