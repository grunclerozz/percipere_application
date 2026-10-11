# Web app API contract — what Percipere needs

Endpoints the web admin app provides. The **books** and **accounts** and **reports** are real
(`HttpAdminBookRepository`, `HttpAccountApi`, `HttpIssueReportApi`). Library sync and image
description still talk to **mocks** (`MockLibrarySyncRepository`,
`MockImageDescriptionRepository`); the real clients replace them behind the same interfaces
(`library_sync_repository.dart`, `lib/core/network/image_description_repository.dart`).

> The dashboard now offers REST URLs under `/api/v1` for everything (its `docs/api-contract.md`
> is the master). Accounts and reports below still use the older `.php` URLs, which keep
> working (deprecated); the app moves to the REST ones in a later update.

All paths are under the web app's base URL (`Env`). JSON is UTF-8. Dates are ISO 8601
(UTC). Errors: a JSON body `{"error": "message"}` with a normal HTTP status. The app is
**offline-first**: every call may fail with no internet, and nothing blocks reading.

Authentication: the Library endpoints for the catalog are **public** (guests read and
download books too). The sync endpoints need the signed-in account's token (Phase 7).

---

## Report an issue — built 2026-10-11 (`POST api/v1/feedback.php`)

**The owner chose to extend the existing feedback endpoint** instead of adding `/api/reports`. The full reference is the dashboard repo's `docs/API.md`; the app's spec is `docs/specs/report-an-issue.md`.

**Request:** a JSON body with:
- `ticket_no` (`PRC-YYYYMMDD-XXXX`), `type`, `module`, `severity` (`null` unless Bug), `description`, `email` (or `null`)
- `app_version`, `os_version`, `device_model`, `source_screen`, `created_at`
- optionally `Authorization: Bearer <token>`, which links the report to the account

**Reply:**
- `201 {"ok": true, "id", "ticket_no", "status": "Open", "linked"}`
- **The same ticket sent again stores nothing new** (`200`, same `id`), so the app can retry safely.

**Errors:**
- `422`: refused. The app keeps the report as failed.
- `429`, `5xx` or no connection: the app keeps it pending and retries later.

**Client:** `lib/core/report/issue_report_api.dart`. Builds without `API_BASE_URL` keep reports pending; there is no mock.

---

## Accounts — built 2026-10-10 (dashboard `api/v1/`)

**The full reference is the dashboard repo's `docs/API.md`.**

**How it differs from the rest of this contract:**
- The paths are plain PHP files under `{API_BASE_URL}/api/v1/`.
- Errors are `{"ok": false, "code": "...", "error": "..."}`.
- The app picks its own words from `code`.

**Endpoints:**
- `register.php`, `verify.php`, `resend.php`
- `login.php`, `logout.php`, `me.php`
- `password_forgot.php`, `password_reset.php`
- `feedback.php` (not used by the app yet)

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
