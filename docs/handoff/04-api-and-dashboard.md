# 04 — API and dashboard

The dashboard is a separate PHP/MySQL repo (`percipere_web`, folder `percipere_dashboard`),
served by XAMPP on the team's PC (checkout under `C:\xampp\htdocs\website\percipere_web\`).
**Its own `docs/api-contract.md` is the master API reference**; this file and the app's
`docs/api-contract.md` describe what the app uses. Dashboard internals are out of scope here.

## Base address
- Build flag `API_BASE_URL` = the dashboard folder URL, e.g.
  `http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard`. REST base = `{API_BASE_URL}/api/v1/`.
- **Fixed at build time (2026-10-19):** there is no setting screen for the address. Without
  `--dart-define=API_BASE_URL=...` the app uses the emulator's `http://10.0.2.2/website/percipere_dashboard`
  (`Env.emulatorBaseUrl`; the Android build allows plain http to that host too). Every API client
  (accounts, books, reports, health, describe, voice models) reads the one
  `serverAddressProvider` (`lib/core/network/server_address.dart`). An unreachable server is
  spoken as "Hindi maabot ang server…" (`serverUnreachable`).
- Requirement (as of 2026-10-13, per the status history in `05-current-status.md`): the app needs the dashboard branch
  **`fix/webapp-api`** (REST routes). It was **not merged** then; current state **unverified**.
- HTTP client: `apiDio()` in `lib/core/network/api_dio.dart` (timeouts + `CleartextGuard`).
- **Cleartext rule (2026-10-17):** `http://` is allowed to private-network hosts (10.x,
  172.16–31.x, 192.168.x), `localhost`/127.x, the build's own `API_BASE_URL` host and
  `API_CLEARTEXT_HOSTS`; everything else needs `https://` (`Env.allowsCleartext`, enforced by
  `CleartextGuard`; Dart's HTTP client ignores Android's network security config, which stays
  strict for the Android stack).
- **Test connection (2026-10-17):** developer Settings row "Subukan ang koneksyon sa server" →
  `lib/core/network/server_health.dart` calls `GET {address}/api/v1/health` (falls back to
  `/api/v1/index.php/health`) and speaks OK or the reason (no network, wrong address, unreachable,
  server down, http blocked, timeout). The health reply has `status` and `time` but **no server
  version**. The Aklatan says briefly whether the server answered.
- Guide for the students: `docs/connection-guide-app.md`.

### Audit of the app's calls (2026-10-17)
All use the fixed server address and `apiDio()` (timeouts, guard):
accounts, books (list/file/cover), reports, the offline-voice model list, image description.
Fixed: image description used the build-time address and a plain `Dio`.
Dashboard endpoints the app uses that the dashboard router (`api/v1/index.php`, branch
`feat/admin-roles`) does **not** have:
- `GET /api/v1/models` (voice-model manifest): the app falls back to `models/manifest.json`, then
  to the GitHub release.
- ~~`POST /api/describe-image`~~ replaced 2026-10-19 by `POST /api/v1/describe` (see below).

## Errors
Success = the plain JSON resource. Failure = `{"error": {"code", "message", "fields"?, "retry_after"?}}`
with an HTTP status. The app chooses its own spoken words from `error.code`.

## Accounts — `lib/core/auth/account_api.dart` (`HttpAccountApi`), `account_service.dart`
| Method + path | Body | Reply |
|---|---|---|
| `POST auth/register` | `full_name`, `email`, `password` | created; `status` is `active` or `pending_approval`. **No email is sent** |
| `POST auth/login` | `email`, `password`, `device` | `{token, user}` |
| `POST auth/logout` | — (Bearer token) | — |
| `GET auth/me` | — (Bearer token) | `{user}` (status check) |
`user` = `{id, full_name, email, status}`. Error codes the app knows: `invalid_credentials`,
`pending_approval`, `account_suspended`, `email_taken`, `too_many_attempts` (+ `retry_after`),
`unauthorized`, `validation_failed`. **Retired (2026-10-18):** `auth/verify`, `auth/resend`,
`auth/password-reset/request` and `auth/password-reset` answer 501 on the dashboard; the app no
longer calls them (no code screens, no password reset for web app accounts yet).
The shape of the register reply beyond `status` is **unverified** (the dashboard repo is not on this
PC): the app reads `status` at the top level or under `user`, and anything but `active` counts as
"waiting", which is tried as a login anyway.

**Flow** (decision log 2026-10-10 (3)):
- Register → `RegisterStatus` (`active` / `pending_approval`) → login is tried at once either way →
  logged in and on to the setup; if the login fails: "Nagawa na ang iyong account. Subukan mong
  mag-log in." and back to Login (`AccountService.register` → `RegisterResult`).
- Login → token stored in secure storage as `api.token.<localUserId>` (never in SQLite). Each
  server account has one local account (`users.server_id`) holding settings and Library; its
  password hash is refreshed at each server login so **offline login** works for accounts
  already used on the tablet.
- Phone-only account logging in with the right password → registered on the server, then logged in.
- Suspended / waiting for approval → reason spoken. "Nakalimutan ang password" is hidden for web app
  accounts (saying it gives "hindi pa available"); phone-only accounts keep the security question.
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
- **Used (2026-10-19):** `GET /api/v1/health` → `vision_enabled` (missing = false, cached 60 s) and
  `POST /api/v1/describe` (multipart `image`, `lang` `fil`|`en`, optional `detail`) →
  `{description, source, model}`; contract in the dashboard repo, `docs/api/describe.md`. Anonymous
  (no user id, no token sent); 10 requests/minute/IP; any non-200 → ML Kit. **The app never calls
  Gemini directly and holds no key.**
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
