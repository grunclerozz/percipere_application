# Aklatan — the Library (Phase 6E)

Status: **PLANNING (2026-10-06).** Requirements from the user. Part A first; Part B only
after the user has tested and approved Part A. Decisions: `decisions.md` (2026-10-06).

A library inspired by Apple Books, adapted for voice and gesture navigation. It holds the
user's own documents and admin books (PDF/EPUB from the web app).

---

# Part A — The Library

## A1. Reading History is replaced
- Library **fully replaces Reading History**. Every existing entry (documents and
  "Larawan" entries) migrates with title, date, type, thumbnail and saved position. No
  data loss. Then the History screen/code is removed.
- "kasaysayan", "history" open the Library, with "aklatan", "library", "mga aklat".
- Scanned/uploaded documents are stored automatically when extraction finishes.
  Maglarawan descriptions are added when the user says "i-save".

## A2. Home screen
Eye logo, Speaking Zone ("Ano ang gusto mong gawin?"), Gesture Pad. Two options:
**Magbasa ng bago** → Capture (Mag-upload, Gamit ang Camera, Maglarawan) · **Aklatan** →
Library. Login, profiling and guest mode end at Home. Back from Capture/Library → Home.
"home"/"simula" → Home from anywhere.

## A3. Library screen (shelves)
Cover tiles with title, author/type, progress bar + percentage, in horizontal shelves:
1. **Ituloy ang pagbasa** — started, not finished, most recent first.
2. **Aking mga dokumento** — own scans/uploads/Maglarawan, newest first.
3. **Mga koleksyon** — the user's collections.
4. **Mga aklat** — admin catalog grouped by category.

Top: search (voice "hanapin ang …" or typing) and filters: Lahat, Aking mga dokumento,
Mga aklat, Na-download, Tapos na, May paborito, and each collection.
Covers: admin books use the web cover; own documents a first-page/photo thumbnail, else a
tile in theme colors with the title in large text.
Navigation: swipe left/right within a shelf, **up/down between shelves**, double-tap opens
details. One short line per item ("Florante at Laura, ni Francisco Balagtas, 45
porsiyento, huling binasa kahapon."); entering a shelf says its name and count. Voice:
"ituloy ang [pamagat]" resumes, "buksan ang [pamagat]" opens details. Empty shelves are
announced helpfully. **New books:** "May mga bagong aklat sa Aklatan." (no number) when the
Library opens with books added since the last visit; "Bago" label until opened or detailed.

## A4. Details screen
Cover, title, author/type, progress %, estimated time left (words × user's TTS speed),
description (books). Focus order: **Ituloy/Basahin** · Basahin mula sa simula · Mga
paborito · Mga kabanata (EPUB, PDFs with outline) · Idagdag sa koleksyon · I-download /
Alisin ang download (books, announces size) · Markahan bilang tapos na/hindi pa tapos ·
Palitan ang pangalan + Burahin (own documents only, with spoken confirmation).

## A5. Favorites (saved spots)
"favorite", "paborito", "i-favorite ito" or a "Paborito" button in the Reader (in focus
order, spoken label) saves the current spot: "Na-save bilang paborito" + haptic. Stores
chapter, sentence, first words as label, date. "Mga paborito" (details) or "mga paborito
ko" (Reader) lists them in reading order ("Kabanata 3: Sa isang madilim na gubat…");
double-tap/"pumunta dito" jumps and continues. Delete with confirmation. Items with a
favorite appear under "May paborito".

## A6. Collections
Created by voice ("gumawa ng koleksyon na [pangalan]") or from the Library (dictation or
typing). Any item (own or book) joins one or more collections from details or by voice
("idagdag sa [koleksyon]"). Shown as a shelf and as filters; same announcements; search
works inside. Rename/delete with confirmation; deleting a collection never deletes items.

## A7. Progress
Exact position = (chapter index, sentence index); percent = sentences read ÷ total. Saved
continuously and on leaving the Reader. Finished at the last sentence: "Tapos mo nang
basahin ang [pamagat]." — leaves "Ituloy ang pagbasa", appears under "Tapos na". Progress,
favorites, collections are per user.

## A8. Admin books: online and download
- Read online: not-downloaded book → fetched into a temporary cache and opened, with
  progress announced.
- Download: permanent for offline; indicator, filter "Na-download", progress and
  completion announced. Free storage is checked first; warn when low.
- Offline: last cached catalog; non-downloaded books announced as needing internet
  ("Kailangan ng internet para mabasa ito. I-download ito kapag may internet.").
- Versions: if the admin updates a downloaded book, offer to update the download, keeping
  progress where possible. If removed, tell the user at the next refresh, keep the progress
  record, mark unavailable.

## A9. Guests and cross-device saving
- First guest download: warn and recommend an account ("Paalala: Naka-save lang ang iyong
  mga aklat sa phone na ito…Gusto mo bang mag-register ngayon?"). Declining continues the
  download. Repeat at most once more, from the Library, never while reading.
- Registering moves the guest's library (documents, downloads, progress, favorites,
  collections) to the account, like the existing guest migration.
- Every library record has a UUID, `synced`, `updated_at`. `LibrarySyncRepository`
  interface + mocked implementation; no real sync (Phase 7).
- **Privacy: the user's own scanned/uploaded documents stay on the device and are never
  uploaded.** Only admin-book data (the user's book list, progress, favorites, collection
  links) is designed to sync. Own-document rows are marked `local_only` so the sync layer
  skips them. Told to users in the registration reminder's follow-up if they ask.

## A10. Formats
- **PDF:** existing pipeline (text layer, OCR fallback); chapters from the outline if any.
- **EPUB:** own parser on `archive` + `xml`: container → OPF spine for order, TOC (nav or
  NCX) for titles, XHTML → plain text keeping paragraphs, dropping scripts/styles/markup.
  Images skipped in Part A, but their position (chapter, paragraph/sentence, src, alt,
  caption) is recorded for Part B. DRM-protected or invalid EPUBs give a clear spoken
  message.
- Reader: "susunod na kabanata"/"next chapter", "nakaraang kabanata"/"previous chapter";
  chapter titles announced when a chapter starts.

## A11. Web app connection (real since 2026-10-11)
`AdminBookRepository` has two implementations: `HttpAdminBookRepository` (the dashboard's
REST API, `GET {API_BASE_URL}/api/v1/books`, `/books/{id}`, `/file`, `/cover`) and
`UnconfiguredBookRepository` for builds without `API_BASE_URL` (no admin books; the Library
says it needs internet). The admins manage the books in the dashboard's Library page
(add/edit, PDF/EPUB, cover, activate/deactivate, categories, languages); the app only reads.
The old mock (3 public-domain sample books, "simulate new book") is now `FakeAdminBookRepository`
in `test/helpers/`, used by tests only; the spoken "magdagdag ng bagong aklat" testing aid is
gone. Endpoints and fields: `docs/api-contract.md`. Downloads are checked against the
server's size and SHA-256.

## A12. Storage
SQLite: library items, favorites, collections, collection–item links. Item fields: owner,
source (camera/upload/description/book), title, author, cover path, format, file path, text
cache reference, chapter list, total sentences, position, percent, last opened, finished;
books add book id, version, downloaded, new. Files in private storage; extracted text
cached. Deleting an item removes file, text cache, cover, favorites and collection links.

## A13. Technical
ARB strings (Filipino default) · all actions via ActionRegistry/CommandBus, new phrases in
the matcher · heavy work off the main thread · text size, themes and text colors apply on
Home, Library and details · back follows app-wide rules · tests as listed in the user's
brief (migration, routing, auto-storage, progress, finished, favorites, collections, new
books notice, EPUB, online/offline/download, updates/removals, guest warning, guest→account,
per-user separation, widget tests). End-of-phase quality check before reporting.

---

# Part B — Images in EPUB books (only after Part A is approved)
Offline Maglarawan labeling when the Reader reaches an EPUB image: "May larawan: puno,
bundok, ilog." (no label above threshold → "May larawan dito."). Publisher alt/caption
first, labels after. Setting "Ilarawan ang mga larawan sa aklat" (default on). "mas
detalyado" requests the online description with the existing consent. Images ahead of the
reading position are processed in the background. Tests: with/without alt, the setting,
threshold fallback.
