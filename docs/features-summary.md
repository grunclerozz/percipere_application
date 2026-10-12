# Percipere: Features Summary

Written on 13 October 2026 from `CLAUDE.md`, everything in `docs/` (specs, API contract, testing checklists, decision log, Percy training reports) and the full git log (22 commits, 1–13 October 2026). It describes the app as it is now, in plain language, for the thesis. Where the documents say a feature is built but not yet tried on the tablet, this summary says so.

---

## 1. Overview

**What it is.** Percipere is an Android app that reads printed and digital text aloud. The user does not need to see the screen. Everything can be done by **gestures** on a Gesture Pad (the lower part of the screen) or by **voice**. The app speaks in **Filipino (default) or English**.

**Who it is for.** People with visual impairment in Bataan, Philippines.

**How it works in daily use.** The user points the camera at a page, or opens a PDF, Word file or picture. The app finds the text, then reads it sentence by sentence with a highlighted subtitle. Every screen announces itself, and every action is confirmed by voice and a short vibration. Every action can be done three ways: by gesture, by voice, or by touching the screen. Screen readers (TalkBack) are also supported.

**Offline and online parts.**

| Works offline (on the tablet) | Needs internet (talks to the web dashboard) |
|---|---|
| Camera scanning and text recognition (OCR) | Creating an account (an emailed code is sent) |
| Reading aloud, gestures, voice commands | Resetting a forgotten password (emailed code) |
| Percy, the voice assistant (runs fully on the device) | Browsing and downloading the admin's books (Aklatan) |
| Basic picture description (Maglarawan, offline labels) | Sending "Report an Issue" tickets and checking their status |
| Own documents, favorites, collections, reading progress | Checking whether an account was suspended |
| Logging in again with an account already used on the tablet | |

Reading never waits for the internet. Anything that needs the internet fails politely and is retried later.

---

## 2. Main features

### 2.1 Reader and OCR

- **Ways to get a document into the app:**
  - **Scan with the camera.** The camera screen gives spoken guidance: too dark, no text found, too far, too close, ready. It takes the photo by itself after four "ready" checks in a row. A double-tap also takes it. If the in-app camera does not work, the phone's own camera app is the fallback.
  - **Upload a file** through Android's file picker: **PDF, DOCX (Word), EPUB** (from the Library) and **images** (JPG, PNG). No storage permission is needed.
- **Text extraction.**
  - Pictures go through on-device OCR.
  - PDFs use their own text layer. Pages with almost no text in it are rendered as images and OCR'd.
  - DOCX files are opened and read directly. EPUB books are read with the app's own parser (chapters, table of contents).
  - Extracted text is cleaned up (garbage lines removed). Poor photos get a spoken offer to retake.
- **Reading.** The text is split into sentences. The current sentence is highlighted and kept in view. The user can play or pause, repeat a sentence, skip a sentence or a paragraph, start from the beginning, and go faster or slower. For EPUB books and PDFs with an outline, the user can jump to the next or previous chapter.
- **Reading position.** It is saved every few sentences, on pause and on exit, so the user can continue later.
- **Reading text size.** A− and A+ buttons, a pinch gesture, or voice. Only the reading text changes size.
- **Language detection.** The app guesses whether a document is Filipino, English or mixed (Taglish), so the right reading voice is used.

### 2.2 Text-to-Speech (TTS)

- Uses the phone's own speech engine (Google's, when installed).
- **Speed:** Mabagal (slow, 0.75) / Katamtaman (normal, 1.0) / Mabilis (fast, 1.5) in setup, plus a speed strip beside the Gesture Pad and finer steps in Settings. Spoken prompts and Percy follow the chosen speed, not only the document.
- **Pitch, reading voice** (female/male when the phone's voices name their gender), and language can be changed in Settings.
- If no Filipino voice is installed, the app tells the user, falls back to English prompts, and (on the Welcome screen) can open the phone's voice settings.
- With TalkBack on, the app sends its messages to TalkBack instead of speaking itself.

### 2.3 Gesture Pad

The lower 30% of most screens is the Gesture Pad. Main gestures:

| Gesture | What it does |
|---|---|
| Swipe right / left | Next / previous option (in the Reader: next / previous sentence) |
| Double-tap | Choose the focused option (in the Reader: read or pause) |
| Single tap | Repeat what the screen just said |
| Swipe up / down | Faster / slower, or bigger / smaller values in setup and Settings |
| Long-press | Listen for a voice command (or dictate into the focused field) |
| Two-finger swipe right | Go back |
| Two-finger swipe down / up | Next / previous paragraph |
| Two-finger double-tap | Stop speaking / pause |
| Two-finger swipe left | Call Percy |
| Three-finger tap | Help for the current screen |

The thresholds are tuned for users who cannot see where their finger is (for example, a swipe must travel at least 48 px; a long-press is 0.65 s). Gestures are switched off while TalkBack is on. The user chooses between **voice mode** and **gesture mode** during setup and can change it later.

### 2.4 Voice Commands

- The user says short commands such as "basahin", "ituloy", "susunod", "bumalik", "bilisan", "kamera", "settings", "tulong", in Filipino or English. The wake word "Percipere" is accepted but not required.
- The command list is global, plus extra phrases for each screen. Yes/no questions accept "oo, opo, sige" and "hindi, huwag, ayoko".
- **Tolerance for recognition errors.** If the best match is only moderately close, the app asks "Ang ibig mo bang sabihin ay …?" instead of guessing (see section 3.4).
- **Fast response.** The app acts on partial results and uses a short end-of-speech pause. The user can speak while the app is reading ("barge-in"); the reading pauses, and resumes if no command was heard.
- Voice is turned on only after the microphone has been explained and allowed. Passwords dictated by voice are hidden from the on-screen text.

### 2.5 Percy, the assistant

Percy is a voice assistant that understands ordinary sentences ("Percy, buksan ang library", "paki-ulit nga") and acts on them.

- **Self-built and offline.** Percy does not call an external AI service. The team wrote the training sentences, trained an **intent classifier** on a computer, and exported it to a file that runs inside the app. The ElevenLabs online version built earlier was kept only as a hidden developer option, off by default and absent in normal builds.
- **How a sentence is handled:** speech recognition → text clean-up → intent classifier → slot filling (for example which book) → dialogue manager → the same action path as gestures → spoken reply.
- **Confidence rules:** at 0.60 or higher Percy acts. Between 0.30 and 0.60 Percy asks "did you mean …?". Below 0.30, or when the sentence is out of scope, Percy says it did not understand and suggests two or three things to say.
- **Opening a book by name.** Percy matches the spoken title against the user's library, accepts "the first / second / last one", and asks which one when several match.
- **Dialogue.** Percy remembers the last few turns, asks follow-up questions, and always confirms destructive actions (delete, logout).
- **Persona.** Replies come from an editable file, in Filipino or English, polite ("po") or casual, and short or talkative, as set in Settings.
- **Session.** Percy starts with a two-finger swipe left or by saying "Percy". It stays in the conversation through a long-press (to talk), a single tap (repeat) and a two-finger double-tap (stop speech). After 9 s of silence it asks once "Nandito pa po ako…", and after 9 s more it says goodbye.
- **Percy analysis panel** (developer builds only). It shows, for each sentence, the transcript, the language (Filipino/English/Taglish), the intent, the confidence, the top three guesses and the action taken. It is kept in memory only (last 20), with no audio, and hides password fields.
- **Training log** for later retraining (Settings, on by default): the sentence, predicted intent, confidence and outcome. It does not include document content.

### 2.6 Accounts, Guest mode, Profiling, Themes, Speech speed

- **Welcome:** Login, Register, or "Subukan muna" (try without an account).
- **Registration:** first name, last name, email, password (at least 8 characters), by dictation or typing. With the web dashboard, a **6-digit code is emailed** and the user says or types it. The password is visible while typing (eye button), as required by the adviser and panel. The app never speaks the password aloud.
- **Login:**
  - Email and password; "stay logged in" is optional; **fingerprint login** is offered.
  - Wrong passwords trigger a growing wait (30 s, doubling, up to 1 h), spoken as a countdown.
  - Accounts already used on the tablet can log in **offline**.
  - A suspended account is told why, and a forgotten password is reset with an emailed code.
- **Guest mode:** everything works without an account. Guests are reminded (once or twice) that their history is only on this phone. When a guest registers, their documents and settings move to the new account.
- **Profiling (setup):** a spoken, step-by-step setup after registration: how the user wants to navigate (voice or gestures), speech speed, pitch, text size, text color, font, theme, and so on. Each change is heard or shown at once, with a summary at the end. It can be redone later ("Ulitin ang setup").
- **Themes and looks:** three high-contrast themes (cream/navy, dark/yellow, dark/white), three bundled fonts (Montserrat, Atkinson Hyperlegible, Lexend), adjustable text size and color. Themes are checked for strong contrast (7:1).
- **Per-account settings:** each account has its own settings, library, favorites and collections.

### 2.7 Tutorial

A guided spoken tutorial that starts with **Percy introducing itself**, then teaches the controls. It runs once after setup: once per account, and once per device for guests. It can be replayed from Settings, by saying "tutorial" / "turuan mo ako" / "paano gamitin", or from Home help.

### 2.8 Aklatan (Library)

Aklatan replaced the old Reading History. After setup, the user arrives at **Home**, which has two options: *Magbasa ng bago* (scan/upload/describe) and *Aklatan*.

- **Shelves:** *Ituloy ang pagbasa* (continue reading), *Aking mga dokumento* (own scans and uploads), *Mga koleksyon* (collections), and *Mga aklat* (the admin's catalog, grouped by category). Each item shows a cover, title, author or type, and a progress bar. The app reads one short line per item.
- **Search and filters:** search by voice ("hanapin ang …") or typing. Filters: all, own documents, books, downloaded, finished, with favorites, and each collection.
- **Details page:** continue or read from the start, favorites, chapters, add to collection, download or remove download, mark finished, rename or delete (own documents only, with spoken confirmation). It estimates time left from the user's speech speed.
- **Favorites:** saved spots in a document ("i-favorite ito"). The user can list them and jump back.
- **Collections:** created by voice or typing; an item can be in several; deleting a collection never deletes the items.
- **Progress:** an exact position (chapter and sentence) and a percentage. Finishing a book moves it to "Tapos na".
- **Admin books and downloads.** The books come from the web dashboard. The user can read one online or download it for offline use. A downloaded file is checked by size and SHA-256 fingerprint before it is accepted. If the admin publishes a newer version, the user is offered an update with the reading position kept. If a book is switched off, the user is told, and progress is kept. New books are announced as "May mga bagong aklat sa Aklatan." and marked "Bago". Offline, the last list stays and books not yet downloaded say they need internet.
- **Guests** may read and download books too, and are reminded once that downloads stay on this phone.

### 2.9 Maglarawan (image description)

Maglarawan tells the user what is in a picture, which helps when a photo has no readable text.

1. The user picks a camera photo or an uploaded image.
2. **Offline first:** the on-device image labeler finds objects. The app says, for example, "Mukhang may pagkain, plato, at mesa sa larawan." The labels are translated into Filipino. If nothing is confident enough, it says so and suggests better light.
3. It also checks for text. If text is found, it offers to read it in the Reader.
4. **Online (optional):** if there is internet, the user may ask for a more detailed description from the server. First use asks for spoken consent, because the picture would be sent to the Percipere server and to Google's service. The answer can be changed in Settings. Guests send anonymously.
5. Safety: every description is worded as an estimate ("Mukhang…"). For medicine, pills or money, the app adds a reminder to confirm with someone trusted. The app never guesses who a person is.

### 2.10 Report an Issue (Mag-report ng problema)

- Reachable from Settings, Home, by saying "mag-report" on any screen, or by asking Percy.
- **One question per page**, each read aloud: type (bug, suggestion, general feedback), part of the app, severity (bugs only: low, medium, high, critical, each explained), a description (spoken or typed, read back to confirm, 10–1000 characters), and an email (pre-filled for accounts, optional for guests). A review page reads everything back before "Ipadala" (send).
- A **ticket number** such as `PRC-20261011-AB3K` is given and read character by character.
- **Sent automatically, safely retried.** The report is saved first, then sent. If the user is offline it waits and is retried. Sending the same ticket twice never creates a duplicate.
- **"Aking mga report"** lists the user's own reports with the status set by the dashboard: *Natanggap* (received), *Ginagawa* (in progress), *Naayos na* (fixed), *Sarado* (closed).
- Automatically attached: app version, Android version, phone model, the screen the report started from, and the time. Never attached: documents, images, book content, voice recordings, passwords, Percy logs.

### 2.11 Settings and Help

- **Settings rows:** reading speed, pitch, language, reading voice, text size, theme, text color, font, navigation mode, vibration, auto-read, how talkative the app is, auto-capture, phone voice settings, Percy's politeness and talkativeness, Percy log, image-description consent, stay logged in, fingerprint login, report an issue, my reports, tutorial, redo setup, and logout. Guests see "Register" instead of account rows.
- **Help:** a three-finger tap or saying "tulong" explains the current screen. There is no separate Help screen; Home carries the report link and the tutorial.
- **Developer-only settings** (shown only in special developer builds): server address, ElevenLabs switch, Percy analysis panel, Percy log export.

---

## 3. Algorithms and AI

### 3.1 Text recognition (OCR)
Google ML Kit text recognition, running **on the device** (Latin script), is used for photos, image uploads and scanned PDF pages. The camera also measures each preview frame for brightness and text presence to give the "too dark / too far / ready" hints.

### 3.2 Image labeling (Maglarawan)
Google ML Kit image labeling, on the device, returns the top labels above 0.7 confidence. A hand-made table translates them to Filipino. The optional detailed description is generated server-side by an online AI service (Gemini) through the dashboard, with instructions to be brief, mention visible text, never identify people, and add safety reminders.

### 3.3 Percy's intent classifier (self-built)
- **Data:** about 529 sentences (527 after removing duplicates) in `intents.csv`, labelled with **27 intents**: open home/library/settings, back, next/previous option, select, cancel, help, where am I, read, pause, resume, stop, repeat, faster, slower, bigger/smaller text, open item, greeting, thanks, goodbye, yes, no, report issue and out of scope. Part of the data was generated as a starter set and part was written by the team.
- **Text preparation:** lowercase, accents removed, punctuation removed, the wake word dropped. Negations such as "hindi", "huwag", "wag" are deliberately kept because they change meaning.
- **Features:** TF-IDF of single words and word pairs, plus TF-IDF of 3- to 5-letter pieces inside each word, so misspellings and speech-recognition slips ("basahen") still score well.
- **Models compared:** Multinomial Naive Bayes and Logistic Regression, trained in Python with scikit-learn. Settings were chosen by **5-fold cross-validation** (tuning on the small validation set alone was found to be noisy).
- **Run on the phone:** the chosen model is exported to a JSON file and evaluated by code written in Dart, with no external AI service. A test checks that the Dart copy gives the same answers as the Python original.
- **Documented accuracy** (held-out test set of 80 sentences, training report of 13 Oct 2026, 27 intents):

  | Measure | Result |
  |---|---|
  | Chosen model | Logistic Regression (C=30, balanced) |
  | Test accuracy | **83.8%** (Naive Bayes: 81.2%) |
  | Macro F1 | 0.667 (Naive Bayes: 0.649) |
  | 5-fold cross-validation, macro F1 | 0.663 ± 0.030 |
  | Accuracy on team-written test sentences only (10) | 100% |
  | Sentences above the "act" threshold (0.60) | 56 of 80, all correct (100%) |
  | "Ask" band (0.30 to 0.60) | 16 sentences, 56% correct |
  | "Did not understand" band (below 0.30) | 8 sentences, 25% correct |

  An earlier run (11 Oct, 513 sentences) reported 88.3% accuracy and macro F1 0.731 on a different split; the figures move because the test set is small. **Honest caveat:** many intents have only 7 to 8 sentences, so per-intent results are noisy (some intents have only one test sentence). The most useful improvement is more sentences written by the team, then retraining with one command.

### 3.4 Levenshtein matcher (voice commands)
The Levenshtein distance counts the fewest single-letter changes that turn one word into another. The app uses it to compare what the speech recognizer heard with every phrase registered for the current screen, after lowercasing and removing punctuation. The similarity score is 1 minus the distance divided by the longer length. The command runs at **0.8 or higher**. Between **0.6 and 0.8**, or when two commands are nearly tied, the app asks for confirmation. Below that, it says it did not understand. A phrase contained in a longer sentence scores high, so "sige, basahin mo na" still matches "basahin". The matcher is the app's own code. (The Word Error Rate use planned for evaluation has not been built yet.)

### 3.5 Other methods worth mentioning
- **Gesture recognition:** a hand-written classifier from raw touch points, including multi-finger gestures.
- **Language detection:** counts common Filipino and English function words (Filipino wins at 40% or more, so Taglish counts as Filipino).
- **Password protection:** PBKDF2-HMAC-SHA256 with 100,000 rounds and a random salt, in the app and on the dashboard.
- **Library title matching:** the same similarity score finds a book from a spoken title.

---

## 4. Connection to the web dashboard

**What the dashboard is.** A separate PHP and MySQL admin web application (repo `percipere_web`, folder `percipere_dashboard`). Admins manage books, accounts and incoming reports there. The app talks to it through a **REST API** under `/api/v1`. The app is built with the server's address. Plain `http://` is allowed only to that one address, for testing; the app refuses it to any other host.

| Area | Endpoints | Data going to the dashboard | Data coming back |
|---|---|---|---|
| Accounts | `auth/register, verify, resend, login, logout, me, password-reset/request, password-reset` | Name, email, password (for login or registration only), the emailed code | A sign-in token, account status (for example suspended) |
| Books | `GET books`, `books/{id}`, `books/{id}/file`, `books/{id}/cover`, `categories` | Nothing about the user (public, no sign-in) | Catalog (title, author, category, language, format, size, SHA-256, version), cover, PDF or EPUB |
| Reports | `POST reports`, `GET reports/{ticket}` | The report, as described in 2.10 | Ticket status |
| Image description | `POST describe-image` (planned, see section 5) | One resized image, language, and user id or "guest" flag | A short description |

**Privacy rules.**
- Scanned or uploaded documents, and everything read from them, **stay on the phone**. They are never uploaded. Only admin-book data is designed to sync.
- Reading, scanning, Percy and voice commands need no internet and send nothing out.
- Passwords are never stored or logged in plain text. The sign-in token is kept in the phone's secure storage. A signed-in report is linked to the account by the token, so the name is not sent.
- Reports never carry documents, images, recordings, passwords or Percy logs.
- Pictures are sent for detailed description only after spoken consent, and guests are anonymous.
- Percy's training log stays on the phone unless a developer exports it.
- Everything is optional for guests, who can use the whole app without sending personal data.
- No outside AI service sees Percy's conversations, unless the developer switch for ElevenLabs is turned on, which normal builds cannot do.

---

## 5. Still mocked or not finished

| Item | State |
|---|---|
| **Detailed image description (online)** | The app side is built, but it still talks to a **stand-in** (`MockImageDescriptionRepository`), not a real server. The `describe-image` endpoint and its AI call (Gemini) are described in the API contract but are not connected. |
| **Library sync across devices** | The design exists (book list, progress, favorites, collections; last write wins), but the app uses a **mock** (`MockLibrarySyncRepository`). Nothing is synced yet; Phase 7. |
| **Account sync (older design)** | A mock also exists in the code, but accounts themselves are real, using the server. |
| **EPUB images (Part B of Aklatan)** | Not started. Describing pictures inside EPUB books waits for approval of Part A. |
| **Core algorithms phase (6D)** | Not built as a separate module: Laplacian-variance (blur check), Otsu thresholding, and Word Error Rate for evaluation. Levenshtein itself is in use inside the command matcher. |
| **Reports, SUS, evaluation, polish (Phases 7 and 8)** | Postponed. |
| **Tablet testing** | Most recent work (voice speed, accounts on the server, reports, Aklatan from the dashboard, Percy changes, the tutorial/speed/password revisions) is built and passes its automated tests, but is **still waiting for the first full tablet test with the real dashboard**. |
| **Dashboard side** | The app needs the dashboard branch `fix/webapp-api`, which has **not been merged** yet; the dashboard database has no books yet. Decisions still open: dropping personal columns from the dashboard database, and rewriting git history that holds old personal data. |
| **Percy data** | Percy needs more team-written sentences; many intents have only 7 to 8. Then retrain. |
| **Planned for later** | "Turuan si Percy" (teaching Percy), learning from corrections, document summaries and question answering. |
| **Cleanup** | Some unused packages are still declared (for example `csv`, `share_plus`, `audio_session`) for future phases. |

---

## 6. Development timeline

Weeks run Monday to Sunday. The git history starts on 1 October 2026 with a baseline commit; the decision log shows that Phases 1 to 6 had been built from 30 September, before the repository existed. The app is version 0.1.1+2, with 72 test files.

### Week 1: 28 Sep to 4 Oct (Phases 1 to 6C)
- **30 Sep (decision log):** Phases 1 to 6 built: foundation, gestures, voice commands, TTS, OCR and the Reader.
- **1 Oct:** Baseline commit of Phases 1 to 6, then a clean new Flutter project; **Phase 6B**: registration, login, profiling (setup), guest mode and back navigation; review fixes (fixed layout, text size only enlarges the reading text).
- **3 Oct:** voice command bug fixes and zoom (pinch) gestures.
- **4 Oct:** **Phase 6C, Maglarawan** (offline image labeling, optional online description, safety messages); standing end-of-phase quality check added to the project rules; crash-proofing and tests.

### Week 2: 5 Oct to 11 Oct (Library, voice speed, Percy, accounts, reports)
- **6 Oct:** draft thesis objectives and scope and limitations; **Phase 6E Part A**, Aklatan, planned and built (Home, shelves, favorites, collections, progress, PDF and EPUB, mocked admin books).
- **7 Oct:** voice response time work (partial results, barge-in); fixes for document inputs failing in the release APK; questions now wait for the answer; online ElevenLabs Percy built (later demoted); a fix commit.
- **10 Oct:** latest app copy brought in; **Phase 9, self-built Percy** (dataset, training, Dart inference, dialogue manager) replaces ElevenLabs as default; voice latency, speed strip and reading voice; **accounts on the web app** (server login, emailed code, reset, suspension).
- **11 Oct:** **Phase 10, Report an Issue**; Percy retrained with `report_issue` and cross-validation; Aklatan loads real books from the dashboard (mock removed); accounts and reports move to the REST URLs; first tablet test prepared (plain HTTP only to the server, server address setting, report status).

### Week 3: 12 Oct to 18 Oct (so far)
- **13 Oct:** project notes updated with current status; **revisions round**: tutorial after setup with Percy's introduction, named speech speeds (slow, normal, fast) with samples, visible password with an eye button, one shared page padding; Percy now stays in the conversation (fixes the "conversation has ended" bug), silence reminder and goodbye, and the developer-only Percy analysis panel; Percy retrained (83.8% test accuracy).
