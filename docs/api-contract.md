# Web app API contract — what Percipere needs

Endpoints the web admin app provides. The **books** and **accounts** and **reports** are real
(`HttpAdminBookRepository`, `HttpAccountApi`, `HttpIssueReportApi`). Library sync and image
description still talk to **mocks** (`MockLibrarySyncRepository`,
`MockImageDescriptionRepository`); the real clients replace them behind the same interfaces
(`library_sync_repository.dart`, `lib/core/network/image_description_repository.dart`).

> The dashboard's REST routes under `/api/v1` (its `docs/api-contract.md` is the master) are
> what the app uses for books, accounts and reports. **The app needs a dashboard that has
> these routes** (the `fix/webapp-api` branch of the dashboard repo, once merged): the older
> `.php` URLs are deprecated there and the app no longer calls them.

All paths are under the web app's base URL (`Env`). JSON is UTF-8. Dates are ISO 8601
(UTC). Errors: a JSON body `{"error": "message"}` with a normal HTTP status. The app is
**offline-first**: every call may fail with no internet, and nothing blocks reading.

Authentication: the Library endpoints for the catalog are **public** (guests read and
download books too). The sync endpoints need the signed-in account's token (Phase 7).

---

## Report an issue — `POST /api/v1/reports` (REST since 2026-10-11)

The full reference is the dashboard repo's `docs/api-contract.md`; the app's spec is
`docs/specs/report-an-issue.md`. (Earlier the app used `api/v1/feedback.php`; that URL still
exists on the dashboard but is deprecated.)

**Request:** a JSON body with:
- `ticket_no` (`PRC-YYYYMMDD-XXXX`)
- `type`, `module` as `{code, label}`; `severity` as `{code, label}` (bugs) or `null`
- `description` (10–1000 characters), `email` (or `null`)
- `reporter`: `{"kind": "account" | "guest", "display_name": null}` (the name is left out on
  purpose; a signed-in report is linked by the token)
- `app_version`, `os_version`, `device_model`, `source_screen`, `created_at`
- optionally `Authorization: Bearer <token>`, which links the report to the account

Codes: type `bug`, `feature`, `feedback`; module `ocr`, `camera`, `voice_commands`,
`accounts`, `text_to_speech`, `gestures`, `library`, `maglarawan`, `percy`, `other`;
severity `low`, `medium`, `high`, `critical`. The labels are the English names the dashboard
shows ("Bug", "Voice Commands", "High", …).

**Reply:**
- `201 {"id", "ticket_no", "status": "open", "linked"}`
- **The same ticket sent again stores nothing new** (`200`, same `id`), so the app can retry safely.

**Errors** (`{"error": {"code", "message", "fields"?}}`):
- `4xx` other than 429 (`422` …): refused. The app keeps the report as failed.
- `429`, `5xx` or no connection: the app keeps it pending and retries later.

**Status:** `GET /api/v1/reports/{ticket_no}` → `{"ticket_no", "status", "updated_at"}`, `status` one
of `open`, `in_progress`, `resolved`, `closed` (archived). The app asks for it whenever "Aking mga
report" opens, for sent reports that are not closed, and shows Natanggap / Ginagawa / Naayos na /
Sarado. Anything unreadable (offline, 404) keeps the last known status.

**Client:** `lib/core/report/issue_report_api.dart`. Builds without `API_BASE_URL` keep reports pending; there is no mock.

---

## Accounts — `/api/v1/auth/*` (REST since 2026-10-11; built 2026-10-10)

**The full reference is the dashboard repo's `docs/api-contract.md`.**

**How it works:**
- Paths are under `{API_BASE_URL}/api/v1/auth/`.
- A success is the plain resource; a failure is `{"error": {"code", "message", "fields"?, "retry_after"?}}`
  with the HTTP status (no `ok` field).
- The app picks its own words from `error.code`.

**Endpoints:**
- `POST auth/register`, `POST auth/verify`, `POST auth/resend`
- `POST auth/login`, `POST auth/logout`, `GET auth/me`
- `POST auth/password-reset/request`, `POST auth/password-reset`
- (The old `register.php`, `login.php`, … still exist on the dashboard; deprecated.)

**Client code:**
- `lib/core/auth/account_api.dart`: the HTTP client.
- `lib/core/auth/account_service.dart`: links server accounts to local accounts.
- Decision log: 2026-10-10 (3).

---

## Books (admin-managed) — built 2026-10-11 (`GET /api/v1/books`, REST)

**The master document is the dashboard repo's `docs/api-contract.md`** (final REST URLs,
every field, errors, the report format, what the dashboard does with them). This section is
what the app's Library uses. Client: `lib/core/library/http_book_repository.dart`
(`HttpAdminBookRepository`); built without `API_BASE_URL`, the Library has no admin books
and says it needs internet (`UnconfiguredBookRepository`).

Base: `{API_BASE_URL}/api/v1`. No sign-in: guests read and download too. Errors are
`{"error": {"code", "message"}}`. Only books the admins switched **on** are listed; a book
switched off just disappears, which the app treats as "removed" (the user is told, progress
is kept, the book is marked unavailable).

| Endpoint | The app uses it for |
|---|---|
| `GET /books?page=&per_page=50&updated_since=` | the catalog, every page until `total` |
| `GET /books/{id}` | before a download: does the book still exist, and what are its size and SHA-256 |
| `GET /books/{id}/file` | the PDF or EPUB (`Content-Length`, `Range` supported) |
| `GET /books/{id}/cover` | the cover (JPEG or PNG); 404 `no_cover` = none |
| `GET /categories` | not used yet (the category name comes with each book) |

A book: `id` (number, kept as text), `title`, `author`, `description`,
`category {id, name}`, `language {id, name, code}`, `format` (`pdf`|`epub`), `file_size`,
`checksum` (`sha256:<hex>`), `version`, `cover_url` (null = none), `file_url`,
`created_at`, `updated_at`.

What the app does with them:
- `language.code` `en` (or an English name) = English reading voice; anything else = Filipino.
- A book it has not seen → **"Bago"** and "May mga bagong aklat sa Aklatan." (no number).
- A downloaded book with a higher `version` → offers to update the download, keeping the
  reading position.
- A download goes to `<file>.part`, is checked against `file_size` and `checksum`, and only
  then renamed; a mismatch leaves nothing on the phone and counts as a failed download.
- The catalog is cached on the phone; offline, the last list stays and not-downloaded books
  say they need internet.

Content rules: only public-domain or properly licensed books. PDF text layer preferred (scans
are OCR'd on the phone); EPUB 2 or 3 without DRM.

---

## Offline voice models — `GET /api/v1/models` (2026-10-15)

The app downloads its own offline command recognizer and voices once (first launch,
`lib/core/offline_voice/`). Client: `HttpModelSource` in `model_installer.dart`.

| Endpoint | The app uses it for |
|---|---|
| `GET /api/v1/models` | the model list (optional: see below) |
| `GET /models/manifest.json` | the same list as a static file — used when the route above is missing |
| `GET /models/<file>.tar.gz` | the archives (`Range` supported → resumable; plain static files are fine) |

Body (either endpoint): `{"models": [...]}` (also accepted: `{"data": [...]}` or a bare list).
Each model: `name` (`percipere-asr-fil-en`, `percipere-tts-tgl` or `percipere-tts-en`),
`version` (text; a higher one replaces the installed model), `size` (bytes), `sha256` (hex, or
`sha256:<hex>`), `url` (absolute, or relative to the server address, e.g.
`models/percipere-tts-tgl-v1.tar.gz`), optional `fallback_url` (the GitHub release copy) and
`installed_size`. Unknown names and entries without a valid size/checksum are ignored. The
ready-made list is `tool/voice_models/manifest.json`. No sign-in.

When neither list can be reached, the app uses the list built into it, which points at the
GitHub release `voice-models-v1`.

---

## Library sync — Phase 7 (designed now, not built)

Only **admin-book data** syncs. The user's own scanned and uploaded documents **never
leave the phone** (privacy); the app marks them `local_only` and the sync layer skips
them. Every record has a client-generated `id` (UUID) and `updatedAt`; the server keeps the
newest `updatedAt` per id (last write wins).

When the same account signs in on another device, its book list, progress, favorites and
collections are restored; downloads can be fetched again.

### `PUT /api/library/books`
The books the user added or downloaded: `[ { "bookId": "...", "downloaded": true } ]`.

### `PUT /api/library/progress`
`[ { "bookId": "...", "chapter": 2, "sentence": 14, "percent": 37.5, "finished": false,
"updatedAt": "..." } ]` — `chapter` and `sentence` are the exact resume position
(`sentence` counted inside the chapter).

### `PUT /api/library/favorites`
`[ { "id": "uuid", "bookId": "...", "chapter": 2, "sentence": 14, "label": "first words",
"updatedAt": "...", "deleted": false } ]`

### `PUT /api/library/collections`
`[ { "id": "uuid", "name": "Paaralan", "bookIds": ["..."], "updatedAt": "...", "deleted":
false } ]` — only book ids are listed; documents in a collection stay on the phone.

### `GET /api/library?since=<date-time>`
Everything above changed after `since`, for a new device:
`{ "books": [...], "progress": [...], "favorites": [...], "collections": [...] }`

---

# Image description — Phase 6C

## `POST /api/describe-image` — detailed image description (Maglarawan)

Request, `multipart/form-data`:

| Field | Type | Notes |
|---|---|---|
| `image` | file | JPEG, longest side ≤ 1600 px (resized and compressed by the app) |
| `language` | `fil` \| `en` | the user's voice language; the description must be in it |
| `user_id` | string | the logged-in user's id; **absent for guests** |
| `guest` | `true` | sent instead of `user_id` for guests: treat as anonymous |

Response `200`, JSON:

```json
{ "description": "Mukhang isang mesa na may …", "has_text": true }
```

- `description`: plain text, ready to be read aloud (no markdown, no lists).
- `has_text`: whether readable text is visible in the image.

Errors: any non-2xx or a body without `description` is treated as "try later".

### Recommended Gemini instructions (set by the web app)

- Describe the image clearly and briefly for a visually impaired listener, in the
  requested language (`fil` = Filipino, `en` = English). Plain sentences, no formatting.
- Start with "Mukhang…" / "It looks like…": it is an estimate.
- Mention any visible text, and say what it is about.
- Do **not** guess who a person is; describe them (clothing, what they are doing).
- For medicines, money, or anything safety-related, add a reminder to confirm with
  someone trusted before using it ("Paalala: kumpirmahin ito sa taong pinagkakatiwalaan
  mo bago gamitin." / "Reminder: please confirm this with someone you trust first.").

### Privacy

The app asks the user once (spoken) before the first upload: the image goes to the
Percipere server and to Google's service. The answer is saved per user and can be
changed in Settings. Guests' requests are anonymous.
