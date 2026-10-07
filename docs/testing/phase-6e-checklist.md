# Phase 6E (Part A) — Aklatan / Library: manual test checklist

Test on the tablet in **both navigation modes** (gestures and voice) and at two text sizes
(default and 48). Use `system-test-checklist.md` for the general checks (wrong input,
spamming, interruptions…). The web app is **mocked**: three sample books (two EPUB, one
PDF) and a way to add a "new" book (see section 9).

## 1. Upgrade from Reading History (do this FIRST, on a phone that has old history)
- [ ] Install over the previous build (do not uninstall). Log in as before.
- [ ] Open the Library: every old document is on **Aking mga dokumento** with its title, type
      (litrato / PDF / Word / larawan (Maglarawan)) and thumbnail.
- [ ] Each old document opens in the Reader **at the sentence where you stopped**.
- [ ] Maglarawan entries still open on the Description screen, with their picture.
- [ ] Items you had started now show a percentage (it appears after the first Library visit).
- [ ] Nothing is missing: count the old entries and the Library items.
- [ ] Two users on the phone: each sees only their own items.

## 2. Home screen
- [ ] After login, after the guided setup and after "Subukan muna" the app opens **Home**
      (eye logo, Speaking Zone "Ano ang gusto mong gawin?", Gesture Pad).
- [ ] Two buttons: **Magbasa ng bago** and **Aklatan** (plus a small Mga Setting link).
- [ ] Magbasa ng bago → Capture (Mag-upload, Gamit ang Camera, Maglarawan). Back → Home.
- [ ] Aklatan → Library. Back → Home.
- [ ] Voice "home" / "simula" goes Home from Capture, Library, details, Settings.
- [ ] Voice "kasaysayan", "history", "aklatan", "library", "mga aklat" open the Library.
- [ ] Voice "camera" / "mag-upload" from anywhere still work, and Back from them goes Home.

## 3. Library screen
- [ ] Spoken entry explains the swipes. Shelves: **Ituloy ang pagbasa**, **Aking mga dokumento**,
      **Mga koleksyon**, then **Mga aklat** (one shelf per category).
- [ ] Swipe right/left moves between items of a shelf; each is one short line, e.g.
      "Florante at Laura, ni …, 45 porsiyento, huling binasa kahapon."
- [ ] Swipe up/down moves between shelves and says "Ituloy ang pagbasa, 3 aytem."
- [ ] The end of a shelf says "Dulo ng istante."; top/bottom say so.
- [ ] Empty shelves are explained ("Wala ka pang dokumento. Mag-scan o mag-upload…").
- [ ] Tiles: cover (or the title on a colored tile in the theme's colors), title, author or
      type, progress bar and %, "Bago" label on new books, a tick on downloaded books.
- [ ] Tiles are readable in all three themes and at text size 48; nothing overlaps.
- [ ] Double-tap an item → its details. "ituloy ang [pamagat]" resumes at once;
      "buksan ang [pamagat]" opens the details. A wrong title says it was not found.
- [ ] A document you just scanned or uploaded is already in **Aking mga dokumento**.
- [ ] A Maglarawan description appears after you say "i-save".

## 4. Search and filters
- [ ] "hanapin [salita]" finds by title or author; "ipakita lahat" clears. The search box
      works by typing too.
- [ ] Filters (chips and voice, e.g. "na-download"): Lahat, Aking mga dokumento, Mga aklat,
      Na-download, Tapos na, May paborito. The Salain control (swipe to it, double-tap)
      goes to the next filter and says how many items.
- [ ] Each of your collections is also a filter, and search works inside it.

## 5. Item details
- [ ] Spoken: title, author or type, progress, time left (changes with the reading speed),
      and the description for books. A new user is not told "Bago" again after this.
- [ ] **Ituloy** (or **Basahin**) is focused first: from the Library, double-tap twice
      resumes reading at the exact sentence.
- [ ] Actions in order: Ituloy/Basahin, Basahin mula sa simula, Mga paborito, Mga kabanata
      (EPUB), Idagdag sa koleksyon, I-download / Alisin ang download (books), Markahan bilang
      tapos na, Palitan ang pangalan + Burahin (own documents only).
- [ ] Books have no Rename or Delete.
- [ ] Rename by dictation works; Delete asks first and removes the item everywhere.
- [ ] Mark as finished / unfinished works and the Library follows (Tapos na filter).

## 6. Reading, progress, favorites
- [ ] Stop in the middle, leave, come back: it resumes at the same sentence.
- [ ] Progress % rises as you read; finishing says "Tapos mo nang basahin ang [pamagat]."
      and the item leaves Ituloy ang pagbasa and shows under Tapos na.
- [ ] Reading a finished item again starts from the beginning and it is unfinished again.
- [ ] **Paborito** button in the Reader (next to A−/A+) and the voice commands "favorite",
      "paborito", "i-favorite ito" say "Na-save bilang paborito" with a vibration.
- [ ] "mga paborito ko" lists them in reading order with their chapter; double-tap or
      "pumunta dito" jumps there and keeps reading; deleting asks first.
- [ ] Mga paborito on the details screen shows the same list; an item with a favorite
      appears under May paborito.

## 7. Collections
- [ ] "gumawa ng koleksyon na Gamot" (or the button, by dictation or typing) creates it.
- [ ] Details → Idagdag sa koleksyon adds/removes the item (own documents and books).
      Voice "idagdag sa Gamot" while an item is focused also works.
- [ ] The collection shows as a shelf and as a filter; opening it lists its items.
- [ ] Rename and Delete (swipe up on a collection tile) ask first; deleting a collection
      **never** deletes its items.

## 8. EPUB and PDF books
- [ ] "Aesop's Fables, Selected" (EPUB): Mga kabanata lists 3 chapters; picking one starts
      there. The chapter title is spoken when a new chapter begins.
- [ ] Voice "susunod na kabanata" / "nakaraang kabanata" in the Reader; at the end/start it
      says so. On a document without chapters it says there are none.
- [ ] "The Tortoise and the Hare" (PDF): chapters from the PDF outline (The Race, The Finish).
- [ ] Images in the EPUB are skipped silently (Part B will describe them).
- [ ] A damaged or DRM-protected EPUB gives a clear spoken message (use your own file).

## 9. Admin books: online, download, offline
- [ ] Opening a book that is not downloaded fetches it ("Kinukuha ang aklat…", 25/50/75 %)
      and opens the Reader.
- [ ] **I-download** announces the size, progress and "Na-download ang …"; the book shows a
      tick and appears under Na-download.
- [ ] Airplane mode: downloaded books open; a book that was never opened says "Kailangan ng
      internet para mabasa ito. I-download ito kapag may internet."
- [ ] **Alisin ang download** removes the file but keeps your progress and favorites.
- [ ] Low storage warning (fill the phone, or test on a nearly full device): asks before
      continuing.
- [ ] **New books:** in the Library say **"magdagdag ng bagong aklat"** (test aid while the
      web app is mocked). It announces "May mga bagong aklat sa Aklatan." (no number), the
      book shows "Bago", and the label goes away once you open it or view its details.
- [ ] (Developer) a new version of a downloaded book offers "I-update ang download?" and
      keeps your place; a removed book is announced and stays as unavailable with its progress.

## 10. Guests
- [ ] First book download as a guest: the registration reminder is spoken as a question.
      "Hindi" continues the download; "oo" opens Register.
- [ ] The reminder repeats at most once more, from the Library, never while reading.
- [ ] Register from the guest: documents, downloaded books, progress, favorites and
      collections are all still there under the new account.

## 11. Accessibility and regression
- [ ] Every new screen announces itself; every action works by voice, gesture and tap.
- [ ] Back (gesture, voice, Android back) never leaves you on a blank screen.
- [ ] Settings, Maglarawan, camera, upload, Reader (pause, skip, speed, text size) still work.
- [ ] Spam: swipe left/right/up/down fast on the Library; double-tap Paborito 5 times (one
      favorite only); spam Back.
