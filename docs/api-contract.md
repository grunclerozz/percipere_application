# Web app API contract — what Percipere needs

Endpoints the web admin app must provide. Today the app talks to a **mock**
(`MockAdminBookRepository`, `MockLibrarySyncRepository`,
`MockImageDescriptionRepository`); the real clients replace the mocks behind the same
interfaces (`lib/core/library/admin_book_repository.dart`,
`library_sync_repository.dart`, `lib/core/network/image_description_repository.dart`).

All paths are under the web app's base URL (`Env`). JSON is UTF-8. Dates are ISO 8601
(UTC). Errors: a JSON body `{"error": "message"}` with a normal HTTP status. The app is
**offline-first**: every call may fail with no internet, and nothing blocks reading.

Authentication: the Library endpoints for the catalog are **public** (guests read and
download books too). The sync endpoints need the signed-in account's token (Phase 7).

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

## Books (admin-managed) — Phase 6E

### Book object
| Field | Type | Notes |
|---|---|---|
| `id` | string | stable id |
| `title` | string | |
| `author` | string | |
| `language` | `"fil"` \| `"en"` | |
| `category` | string | category name (shelf title in the app) |
| `description` | string | short, read aloud on the details screen |
| `format` | `"pdf"` \| `"epub"` | |
| `fileSize` | integer | bytes; the app announces it before a download |
| `coverUrl` | string \| null | |
| `version` | integer | **must increase whenever the file is replaced** |
| `createdAt` | date-time | |
| `updatedAt` | date-time | |
| `active` | boolean | `false` once an admin removed the book |

### `GET /api/books`
The catalog.

Query: `page` (default 1), `pageSize` (default 50), `category` (name), `q` (search in
title/author), `since` (date-time: only books created **or changed** after it, **including
inactive ones**, so the app learns about removals).

Response: `{ "items": [Book], "page": 1, "pageSize": 50, "total": 3 }`

The app reads every page, then:
- books it has not seen → shown as **"Bago"** and announced ("May mga bagong aklat sa
  Aklatan.", no number);
- a downloaded book with a higher `version` → offers to update the download, keeping the
  reading position;
- `active: false` (or a book that disappears) → the user is told, the progress record is
  kept and the book is marked unavailable.

### `GET /api/books/{id}`
One book (Book object). 404 if it never existed.

### `GET /api/books/{id}/file`
The PDF or EPUB bytes (`Content-Type: application/pdf` or `application/epub+zip`), with
`Content-Length` so the app can announce progress, and `Accept-Ranges` if possible.
- **PDF**: text layer preferred; scanned pages are OCR'd on the phone. A PDF outline gives
  the chapters.
- **EPUB**: EPUB 2 or 3, **no DRM** (DRM-protected files are rejected with a spoken
  message). The spine gives the chapter order, the nav document or NCX the titles. Images
  are allowed (Part B describes them on the phone). Prefer `alt` text on images.
- 404 / 410 if the book was removed.

### `GET /api/books/{id}/cover`
The cover image (JPEG or PNG, about 300 × 400 px is enough). 404 if none.

### `GET /api/categories`
`{ "items": [ { "name": "Pabula", "count": 12 } ] }`

### Content rules
Only public-domain or properly licensed books. The app reads files aloud and stores
extracted text on the phone.

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
