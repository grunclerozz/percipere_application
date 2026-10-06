# Percipere — Objectives of the Study and Scope and Limitations (Draft)

Prepared 2026-10-06 from the actual code of the mobile app (`lib/`, `pubspec.yaml`,
`android/`, database migrations, ARB strings, tests) and from `docs/`. The web app's code
was not available, so everything about it comes from `docs/api-contract.md` and from the
team's current objectives, and is marked **to be confirmed by the team**.

Nothing in the app code was changed for this document.

**Status legend**

| Status | Meaning |
|---|---|
| **Built** | Implemented, tests pass, and reviewed or tested on the device in an earlier phase |
| **Built, needs device testing** | Implemented and tests pass, but not yet confirmed on the tablet |
| **Partly built** | Some of the specification is missing (stated in the row) |
| **Mocked** | Works in the app against a stand-in; needs the web app (Phase 7) |
| **Postponed** | Planned, not built (Phase 6D, Phase 7, Phase 8, Part B of 6E) |

---

## 1. Feature Inventory

### 1.1 Features

| # | Feature | Module | What it does | Status | Where (main files) |
|---|---|---|---|---|---|
| 1 | Welcome screen | Account | Opens the app with Login, Register and "Subukan muna" (try first); voice and gestures both active. | Built | `features/welcome/welcome_screen.dart` |
| 2 | Registration | Account | Creates a local account from first name, last name, email and password, filled by dictation or typing. | Built | `features/auth/register_screen.dart`, `voice_form.dart`, `core/auth/validators.dart` |
| 3 | Security question | Account | Stores one security question and answer at registration, used to recover the password. | Built | `features/auth/security_question_screen.dart` |
| 4 | Login | Account | Logs in with email and password; remembers the account on the device. | Built | `features/auth/login_screen.dart`, `core/auth/session.dart` |
| 5 | Password recovery | Account | Resets the password by email, security question and a new password; says that the administrator can also reset it. | Built | `features/auth/forgot_password_screen.dart` |
| 6 | Login lockout | Account | Locks login and recovery after repeated failures (30 s, growing to 1 h) with a spoken countdown. | Built | `core/auth/login_throttle.dart`, `features/auth/lockout_countdown.dart` |
| 7 | Password protection | Account | Stores passwords only as salted PBKDF2-HMAC-SHA256 hashes; never read back or logged. | Built | `core/auth/password_hasher.dart` |
| 8 | Fingerprint login | Account | Offers fingerprint login after registration and uses it on later logins, with the password as fallback. | Built | `core/auth/biometrics.dart`, `features/auth/fingerprint_offer_screen.dart` |
| 9 | Stay logged in | Account | Keeps the user signed in using Android secure storage (can be switched off). | Built | `core/auth/session_store.dart` (flutter_secure_storage) |
| 10 | Guest mode ("Subukan muna") | Account | Lets a person try the app without an account; data stays on the device; short setup; spoken reminders to register. | Built | `core/auth/guest_reminders.dart`, `core/widgets/guest_reminder_on_entry.dart`, `core/auth/account_repository.dart` |
| 11 | Guest to account upgrade | Account | A guest who registers keeps their documents, library, collections and preferences. | Built | `account_repository.dart` (`migrateGuest`), `features/auth/auth_choice_screen.dart` |
| 12 | Old name+PIN account upgrade | Account | Claims an account made before Phase 6B and gives it an email and password, keeping settings and history. | Built | `features/auth/legacy_account_screen.dart`, `upgrade_account_screen.dart`, `legacy_pin.dart` |
| 13 | Several accounts per device | Account | Each user has their own preferences and library on the same device. | Built | `core/db/migrations.dart` (`user_id` columns) |
| 14 | Account sync to the web app | Account | Queues new accounts for upload to the web app (guests are never sent). | Mocked | `core/auth/account_sync_repository.dart` (`synced`, `server_id` columns exist; nothing is sent) |
| 15 | Guided setup (profiling) | Customization | Ten spoken steps: voice or gestures, can you see text, text size, text color, voice language, speed, tone, theme, vibration, auto-read, summary; guests get a short version; can be redone from Settings. | Built | `features/setup/setup_flow.dart`, `profiling_screen.dart`, `setup_labels.dart` |
| 16 | Reading speed and tone | Customization | Sets the TTS speed and pitch (also changed live while reading). | Built | `core/tts/reading_rate.dart`, `core/settings/app_settings.dart` |
| 17 | Voice language and document voice | Customization | Sets the app's language (Filipino or English) and whether documents are read in an automatically detected, Filipino or English voice. | Built | `app/locale_provider.dart`, `core/tts/language_detector.dart`, `speech_language.dart` |
| 18 | Text size | Customization | Adjusts text size in Settings, A−/A+ buttons, pinch and voice in the Reader. | Built | `core/settings/app_settings.dart`, `features/reader/reader_screen.dart` |
| 19 | Themes and text color | Customization | Offers high-contrast themes and text colors that are valid for the chosen theme. | Built | `app/theme/`, `config/palette.dart` |
| 20 | Font choice | Customization | Chooses between three bundled fonts: Montserrat, Atkinson Hyperlegible and Lexend. | Built | `app/theme/theme_settings.dart`, `assets/fonts/` |
| 21 | Vibration (haptics) | Customization | Gives a vibration with confirmations and errors (can be switched off). | Built | `core/accessibility/haptics.dart` |
| 22 | Spoken detail (verbosity) | Customization | Brief, normal or detailed screen announcements. | Built | `core/settings/app_settings.dart` (`Verbosity`) |
| 23 | Auto-read and auto-capture | Customization | Starts reading automatically after a scan; takes the photo automatically when the text is steady. | Built | `app_settings.dart`, `features/camera/camera_screen.dart` |
| 24 | Settings screen | Customization | Lists every setting above plus consent, system TTS voices, fingerprint, stay logged in, redo setup, register (guests) and logout; each is changed by voice, gesture or touch. | Built | `features/settings/settings_screen.dart`, `setting_items.dart` |
| 25 | Preferences per profile | Customization | Saves each setting per user in SQLite (device-wide when nobody is logged in). | Built | `core/db/daos/preferences_dao.dart` |
| 26 | Gesture navigation | Navigation | 12 predefined gestures (see 1.2) with a Gesture Pad on most screens. | Built | `core/gestures/` |
| 27 | Voice navigation | Navigation | About 35 predefined voice commands in Filipino and English, plus spoken yes/no answers and per-screen commands (see 1.2). | Built | `core/voice/`, `core/accessibility/command_bus.dart` |
| 28 | Voice mode or gesture mode | Navigation | The user chooses voice or gestures at setup and can switch by saying "pa-boses" or "pa-galaw". | Built | `core/accessibility/navigation_mode.dart` |
| 29 | Screen announcements and focus | Navigation | Every screen speaks its name, options and a hint; swiping moves focus through the options. | Built | `core/accessibility/announcer.dart`, `focus_controller.dart`, `accessible_screen.dart` |
| 30 | Back navigation | Navigation | One consistent Back on every screen (two-finger swipe right, "bumalik", Android back); Home is the base of the stack. | Built | `app/router.dart`, `command_bus.dart` |
| 31 | Home screen | Navigation | Offers "Magbasa ng bago" (read something new) and "Aklatan" (Library), plus Settings. | Built, needs device testing | `features/home/home_screen.dart` |
| 32 | Help | Navigation | Three-finger tap or "tulong" explains the gestures and commands of the current screen. | Built | `command_bus.dart`, `nav_intent.dart` |
| 33 | Capture screen | OCR | Chooses between uploading a file, using the camera, or Maglarawan. | Built | `features/capture/capture_screen.dart` |
| 34 | Camera with spoken guidance | OCR | Tells the user when it is too dark, there is no text, to move closer or back, or to hold steady; photographs automatically. | Built | `features/camera/camera_guidance.dart`, `camera_screen.dart`, `camera_session.dart` |
| 35 | OCR of photos and images | OCR | Extracts text from a photo or a JPG/PNG upload on the device (ML Kit, Latin script), cleans it into paragraphs and checks its quality. | Built | `core/ocr/ocr_service.dart`, `text_cleanup.dart`, `core/extraction/document_extractor.dart` |
| 36 | Upload of files | OCR | Picks JPG, JPEG, PNG, PDF or DOCX files through the Android file picker (no storage permission). | Built | `features/upload/document_picker.dart` |
| 37 | PDF text extraction | OCR | Reads the text layer of a PDF and applies OCR to pages that are scanned images. | Built, needs device testing (real PDF parsing only tested with fakes in the Library path) | `core/extraction/pdf_extractor.dart` (pdfrx) |
| 38 | DOCX text extraction | OCR | Extracts the text of Word (.docx) files. The older `.doc` format is not supported. | Built | `core/extraction/docx_extractor.dart` (archive, xml) |
| 39 | Text-to-speech reading | TTS | Reads text aloud sentence by sentence using the phone's TTS voices, choosing a Filipino or English voice. | Built | `core/tts/tts_service.dart`, `chunker.dart` |
| 40 | Reader | TTS | Shows the text and reads it with pause, resume, repeat, next and previous sentence or paragraph, faster, slower, text size and read from start. | Built | `features/reader/reader_controller.dart`, `reader_screen.dart`, `core/widgets/document_box.dart` |
| 41 | Offline operation of the core | TTS | Capture, OCR, reading, accounts and the Library of own documents work without internet (subject to installed voices and speech packs). | Built | whole app (`sqflite`, ML Kit on-device) |
| 42 | Library (Aklatan) | Library | Replaces the old Reading History: shelves for continue reading, own documents, collections and books by category; every old history entry is migrated. | Built, needs device testing | `features/library/library_screen.dart`, `core/db/migrations.dart` (v4) |
| 43 | Search and filters | Library | Searches by title or author and filters by own documents, books, downloaded, finished, with favorites and by collection. | Built, needs device testing | `core/library/library_view.dart`, `library_controller.dart` |
| 44 | Item details | Library | Shows progress, time left and description and offers ordered actions: continue, read from start, favorites, chapters, add to collection, download, mark finished, rename, delete. | Built, needs device testing | `features/library/item_details_screen.dart` |
| 45 | Reading progress | Library | Saves the exact (chapter, sentence) position and percentage; resumes there; marks items finished. | Built, needs device testing | `library_dao.dart`, `reader_controller.dart` |
| 46 | Favorites | Library | Saves a spot in a document with the Paborito button or voice, lists them and jumps to one. | Built, needs device testing | `features/library/favorites_screen.dart`, `reader_screen.dart` |
| 47 | Collections | Library | Creates, renames and deletes named collections and adds items to them (deleting a collection never deletes its items). | Built, needs device testing | `library_dao.dart`, `library_screen.dart` |
| 48 | Chapters | Library | Lists the chapters of EPUB and PDF books (from the book's table of contents or the PDF outline), lets the user jump and says the chapter title when it begins. | Built, needs device testing | `features/library/chapters_screen.dart`, `core/library/epub_parser.dart`, `book_content.dart` |
| 49 | EPUB reading | Library | Reads EPUB books (spine, chapter titles, paragraphs); detects damaged and DRM-protected files; images are skipped. | Built, needs device testing (tested with generated sample books only) | `core/library/epub_parser.dart` |
| 50 | Admin books: catalog, read online, download | Library | Lists books published by the administrator, reads them online through a temporary cache or downloads them for offline use, shows size and progress and checks free space. | Mocked | `core/library/admin_book_repository.dart`, `library_service.dart`, `core/platform/storage_info.dart` |
| 51 | Admin books: updates, removals, new-book notice | Library | Announces new books, offers to update a downloaded book that changed (keeping the user's place) and keeps progress for a removed book. | Mocked | `library_dao.dart` (`syncCatalog`), `library_screen.dart` |
| 52 | Remove download | Library | Deletes the downloaded file but keeps progress, favorites and collections. | Built, needs device testing | `library_service.dart` |
| 53 | Library sync to the web app | Library | Designed to upload admin-book progress, favorites and collections (`uuid`, `synced`, `updated_at` columns exist); own documents never sync. | Mocked | `core/library/library_sync_repository.dart` |
| 54 | Guest warnings in the Library | Library | Warns a guest on the first download that books are saved only on this phone and asks about registering. | Built, needs device testing | `library_actions.dart`, `guest_reminders.dart` |
| 55 | Maglarawan — offline description | Maglarawan | Describes a photo with general labels, on the device, without internet, and reads any text found in it. | Built | `features/describe/`, `core/describe/image_labeler.dart`, `label_description.dart`, `config/image_labels_fil.dart` |
| 56 | Maglarawan — detailed description | Maglarawan | After the user's consent, sends the (resized) image to the web app for a detailed description from Gemini ("mas detalyado"); the app holds no API key. | Mocked | `core/network/image_description_repository.dart`, `describe_controller.dart` |
| 57 | Maglarawan consent | Maglarawan | Asks once, by voice, before the first upload and remembers the answer (changeable in Settings). | Built | `app_settings.dart` (`DescribeConsent`) |
| 58 | Save a description to the Library | Maglarawan | "I-save" stores the description and a thumbnail as a library item. | Built, needs device testing | `describe_controller.dart` |
| 59 | Connectivity check | Maglarawan | Detects whether the phone is online before offering the detailed description. | Built | `core/network/connectivity.dart` |
| 60 | Reports and feedback | Reports | Intended to send reports and feedback to the web app. The voice command "ulat / report / feedback" exists but answers "feature not ready"; the offline queue table (`outbox`) exists and is not used. | Postponed (Phase 7) | `command_bus.dart` (`NavIntent.report`), `migrations.dart` (`outbox`) |
| 61 | Usage logs | Reports | Intended to record anonymous usage events. The `usage_logs` table exists, but no code writes to it. | Postponed (Phase 7) | `migrations.dart` |
| 62 | System Usability Scale questionnaire | Evaluation | Intended to collect and score the ten SUS answers in the app. The `sus_responses` table exists; there is no screen. | Postponed (Phase 7) | `migrations.dart` |
| 63 | Word Error Rate calculation | Evaluation | Intended to compute WER (Levenshtein) in the app. The `wer_results` table exists; no calculation code exists. | Postponed (Phase 6D) | `migrations.dart`, `docs/specs/algorithms.md` |
| 64 | Blur check and binarization (Laplacian variance, Otsu) | OCR | Planned image-quality and preprocessing algorithms. | Postponed (Phase 6D) | `docs/specs/algorithms.md` |
| 65 | Description of images inside EPUB books | Library | Planned: describe the pictures in a book offline, with a setting and "mas detalyado". The parser already records image positions and alt text. | Postponed (Part B of 6E) | `epub_parser.dart` (image data only) |
| 66 | System evaluation and final polish | — | Planned. | Postponed (Phase 8) | — |

### 1.2 Gestures and voice commands (as coded)

**Gestures (12 bound).** One-finger swipe right = next; swipe left = previous; swipe up =
faster; swipe down = slower; single tap = repeat; double tap = activate; long press =
listen (voice command). Two-finger swipe right = back; two-finger swipe down / up = next /
previous paragraph; two-finger double tap = stop speech; three-finger tap = help. Pinch
changes the text size in the Reader. (A thirteenth gesture type, two-finger swipe left, is
recognized but not bound.)

**Voice commands (Filipino and English).** select/open, read, pause, resume, stop, repeat,
next, previous, next/previous paragraph, read from start, back, faster, slower, bigger,
smaller, camera, capture, upload, save, library ("aklatan", "mga aklat", "kasaysayan",
"history"), next/previous chapter, favorite, my favorites, settings, help, home, report
(not yet functional), voice mode and gesture mode. Each screen adds its own commands (for
example "hanapin [salita]", "ituloy ang [pamagat]", "gumawa ng koleksyon na [pangalan]",
"idagdag sa [koleksyon]", "submit / tapos na" on forms).

### 1.3 Data stored on the device (SQLite, schema version 4)

`users`, `preferences`, `login_attempts`, `library_items`, `library_favorites`,
`library_collections`, `library_collection_items`. Prepared but unused: `usage_logs`,
`outbox`, `sus_responses`, `wer_results`. `documents` and `documents_v3` were replaced by
the Library; `documents_legacy` is a safety copy kept until a later migration.

### 1.4 Main packages and technologies actually used

| Area | Technology (package) |
|---|---|
| Framework and language | Flutter, Dart (SDK ^3.13) |
| State and navigation | flutter_riverpod 3, go_router |
| Local database | SQLite through sqflite (versioned migrations) |
| Text recognition (OCR) | Google ML Kit text recognition (`google_mlkit_text_recognition`), on device |
| Image labeling | Google ML Kit image labeling (`google_mlkit_image_labeling`), on device |
| Speech recognition | `speech_to_text` (Android's speech recognizer) |
| Text-to-speech | `flutter_tts` (Android TTS), `audio_session` |
| Camera and pictures | `camera`, `image_picker`, `image` (resizing) |
| Documents | `file_picker` (Android file picker), `pdfrx` (PDF), `archive` and `xml` (DOCX and EPUB) |
| Security | `crypto` (PBKDF2-HMAC-SHA256), `flutter_secure_storage`, `local_auth` (fingerprint) |
| Network | `dio`, `connectivity_plus` |
| Device features | `vibration`, `permission_handler`, `android_intent_plus`, `device_info_plus`, `package_info_plus`, a small Kotlin channel for free storage |
| Other | `uuid`, `intl` (English and Filipino localization), `csv`, `share_plus` (declared; not used by any current feature) |
| Fonts | Montserrat, Atkinson Hyperlegible, Lexend (bundled) |
| Testing | flutter_test, mocktail, sqflite_common_ffi (40 test files) |
| Platform | Android only; `minSdk` 24 (Android 7.0) |
| Web app (from the team's objectives, not verified) | HTML, CSS, JavaScript, MySQL |

---

## 2. Comparison with Current Objectives

### 2.1 Objectives that match what is built

| Current item | Matches | Note |
|---|---|---|
| a. Registration module | Yes, and more | Now also login, recovery, guest mode and fingerprint; rename "account module". |
| b. Customization of speed, text size and color | Yes, partly | The app customizes more (see 2.3). |
| c. Navigation by touch gestures and voice commands | Yes | |
| d. Camera capture and OCR of images and uploaded files | Yes | Uploads are JPG, PNG, PDF and DOCX. |
| e. Text to speech | Yes | |

### 2.2 Objectives that are outdated or not built

| Current item | Problem |
|---|---|
| f. "Inventory module" (storing and organizing scanned text) | Replaced by the **library module** (Aklatan): shelves, search, filters, favorites, collections, progress and admin books. The Reading History no longer exists. |
| g. Report module (send reports and feedback) | **Not built.** The command exists but says the feature is not ready; no report screen. Planned for Phase 7. |
| h. Report management module (web) | Web app. **To be confirmed by the team.** |
| i. Report generation module (web) | Web app. To be confirmed. |
| j. AI summarization module with the Gemini API (web) | Web app. To be confirmed. Note that Gemini is also used for Maglarawan descriptions. |
| k. Export module (PDF, Excel, CSV) (web) | Web app. To be confirmed. |
| l. Email module (web) | Web app. To be confirmed. |
| m. Administration module (accounts and settings) (web) | Web app. To be confirmed; it must now also manage books (see Section 3). |
| Software requirements | Missing ML Kit, Flutter packages and Gemini; lists Windows 10 but the app needs an Android 7.0 or newer device (minSdk 24). |
| Evaluation: WER "of the text-to-speech output" | Conflicts with the scope (voice command recognition); see Section 4.5. The in-app WER calculation is not built (Phase 6D). |
| Scope: "Word documents" | Built, but only `.docx`, not `.doc`. |
| Scope: "font" customization | **Built** (three fonts). Keep. |
| Scope: "accessibility customization (reading speed, text size, font, color)" | Built; add voice language, pitch, theme, vibration, auto-read and spoken detail. |
| Scope: "the web-based application does not perform OCR, speech recognition, gesture recognition, or TTS" | Still true, but the web app now also relays image descriptions to Gemini and serves books. Update. |
| Scope: "core reading functions are designed to work offline" | True. Add the exceptions: admin books that are not downloaded, detailed image descriptions, and sync. |

### 2.3 Built features missing from the current objectives

1. **Guided profiling setup** (ten spoken steps, short version for guests, redo from Settings).
2. **Customization beyond speed, text size and color:** voice language, document voice, pitch, theme, font, vibration, auto-read, auto-capture, spoken detail.
3. **Login, password recovery, lockout, fingerprint login, stay logged in** and the upgrade of old accounts.
4. **Guest mode** and moving a guest's data to a new account.
5. **Home screen** and consistent **back navigation**.
6. **Camera guidance** (spoken help and automatic capture).
7. **Maglarawan** (offline general labels, and detailed descriptions through the web app with consent).
8. **Library**, including admin books (EPUB and PDF, read online or download), chapters, progress by sentence, favorites and collections.
9. **Help** command and spoken screen announcements with adjustable detail.
10. **Bilingual interface** (Filipino and English): mentioned in the scope but not in the objectives.
11. **Web side:** book management and image-description relay (see Section 3).

---

## 3. Web App Dependencies

*All entries are **to be confirmed by the team** against the web app. The mobile app
currently talks to mocks; the real clients replace them behind the same interfaces.*

| Mobile feature | What it needs from the web app | Contract | Mobile status |
|---|---|---|---|
| Image descriptions with Gemini | `POST /api/describe-image` (JPEG up to 1600 px, `language`, `user_id` or `guest`); returns `description` and `has_text`; the web app holds the Gemini key and instructions. | `api-contract.md` | Mocked |
| Book catalog | `GET /api/books`, `GET /api/books/{id}`, `GET /api/categories` | `api-contract.md` | Mocked |
| Book files and covers | `GET /api/books/{id}/file`, `GET /api/books/{id}/cover` (PDF or EPUB; public domain or licensed only) | `api-contract.md` | Mocked |
| Book management by admins | Upload, edit, categorize, publish, update and remove books; the app expects updated versions and removals to show in the catalog. The admin screens themselves are not in the contract. | implied | Mocked |
| Library sync | `PUT /api/library/books`, `/progress`, `/favorites`, `/collections` and `GET /api/library?since=` (admin-book data only; own documents never sync; needs the account token) | `api-contract.md` | Mocked (Phase 7) |
| Account sync | Receive new accounts; no endpoint is written in the contract yet. | `account_sync_repository.dart` | Mocked (Phase 7) |
| Receiving reports and feedback | Endpoint(s) for reports and feedback from the app's outbox | **not yet in the contract** | Postponed (Phase 7) |
| Usage logs | Receive anonymous usage events | **not yet in the contract** | Postponed (Phase 7) |
| SUS results | Receive SUS answers and scores | **not yet in the contract** | Postponed (Phase 7) |
| Report generation, AI summaries, export (PDF, Excel, CSV), email, user and system administration | Web-only functions in the current objectives; the mobile app does not call them. | current objectives | Team to confirm |

---

## 4. Revised Objectives (Draft)

**Objective of the Study**

The main objective of this study is to develop **Percipere: A Gesture and Voice-Controlled
Assistive Reading Application for the Visually Impaired Community of Bataan**.

Specifically, the study aims to:

1. Design an Android-based application that is capable of:
   a. Registering users, authenticating them through a password or fingerprint, allowing guest access, and storing their information and app preferences through an account module;
   b. Personalizing the reading speed, voice tone, voice language, text size, text color, font, theme, vibration, and automatic reading through a customization module that is set up through a guided profiling process;
   c. Navigating the application using touch gestures and voice commands through a navigation module;
   d. Capturing printed text through the device camera with spoken guidance, and extracting text from captured images and uploaded image, PDF, and Word (.docx) files through an optical character recognition (OCR) module;
   e. Converting extracted text into spoken audio through a text-to-speech (TTS) module;
   f. Describing images offline through general labels, and providing detailed descriptions through the web application with the user's consent, through an image description (Maglarawan) module;
   g. Storing and organizing scanned documents and administrator-provided books (PDF and EPUB) with reading progress, favorites, and collections through a library module; and
   h. Sending user reports and feedback to the web application through a report module.

2. Design a Web-based application that is capable of:
   a. Receiving and storing the reports and feedback submitted from the mobile application through a report management module;
   b. Producing usage, usability, and feedback reports through a report generation module;
   c. Summarizing report data using the Gemini API through an AI summarization module;
   d. Exporting reports in PDF, Excel, and CSV formats through an export module;
   e. Delivering reports to intended recipients through an email module;
   f. Providing detailed image descriptions to the mobile application using the Gemini API through an image description module;
   g. Managing the books that are available to the mobile application, including adding, categorizing, updating, and removing books, through a book management module; and
   h. Managing user accounts and system settings through an administration module.

3. Create a system using HTML, CSS, JavaScript, and MySQL for the web application, and Dart (Flutter), SQLite, and Google ML Kit for the Android application as software requirements; and a computer system running Windows 10 or higher, an Android smartphone or tablet running Android 7.0 or higher with a built-in camera and microphone, and a stable Wi-Fi or internet connection, as hardware requirements.

4. Evaluate the usability and effectiveness of Percipere, using the System Usability Scale (SUS) to assess user-perceived usability, a supplementary Likert-scale questionnaire to gather user feedback, and **one of the following** sentences about Word Error Rate (WER):

   **Version A (voice command recognition, matches the current scope):**
   "…and the Word Error Rate (WER) to assess the accuracy of voice command recognition."

   **Version B (text-to-speech output, matches the current objectives):**
   "…and the Word Error Rate (WER) to assess the accuracy of the text-to-speech output, by comparing the text the application reads aloud with a transcription of what is heard."

   *Recommendation:* Version A. The app already recognizes spoken commands through the
   phone's speech recognizer, so WER can be computed by comparing each spoken command with
   the text that was recognized. WER measured on TTS output would require a separate
   speech-to-text step on the TTS audio. If A is chosen, the scope sentence needs no change.

Notes on the draft: items 1.h and 2.a to 2.e, 2.h and the "image description" and "book
management" web items depend on Phase 7 and on the web app; confirm they will be finished
before the evaluation (Questions 1 and 2). If WER is kept, the in-app calculation
(Phase 6D) must also be finished, or WER must be computed outside the app from recorded
results (Question 3).

---

## 5. Possible Additions if Completed in Time

- Description of the images inside EPUB books, offline, with a setting to turn it on and a "more detailed" option (Phase 6E, Part B).
- In-app calculation of WER and storage of results (Phase 6D).
- Image-quality checks and preprocessing for OCR (blur detection and binarization) (Phase 6D).
- In-app System Usability Scale questionnaire, spoken and answered by voice or gesture (Phase 7).
- Anonymous usage logs sent to the web application (Phase 7).
- Automatic synchronization of accounts, progress, favorites, and collections across devices (Phase 7).
- Final evaluation fixes and polish (Phase 8).

*(If the team confirms that reports, feedback, SUS and sync will be built before the
evaluation, they move into the objectives in Section 4; items 1.h and 2.a to 2.e already
assume this.)*

---

## 6. Scope and Limitations Updates (Draft)

*Paragraphs to replace or add. Wording follows the current section.*

**Replace paragraph 1 (system):**
This study covers the design, development, and evaluation of Percipere: A Gesture and
Voice-Controlled Assistive Reading Application for the Visually Impaired Community of
Bataan. The system consists of an Android-based mobile application and a web-based
administrative application.

**Replace paragraph 2 (mobile application):**
The mobile application allows users to capture text through the device camera, which
gives spoken guidance on lighting and distance, or to upload images (JPG and PNG), PDF
files, and Word (.docx) files, extract the text, and listen to it through text-to-speech
(TTS). Users can create an account, log in with a password or fingerprint, or try the
application as a guest. A guided setup lets users personalize the reading speed, voice
tone, voice language, text size, text color, font, theme, vibration, and automatic reading.
Users navigate through a predefined set of touch gestures and voice commands, and the
application announces every screen aloud. The application supports English and Filipino,
and its core reading functions are designed to work offline.

**Add (Library and admin books):**
The mobile application includes a library, which keeps the documents the user has scanned
or uploaded and the books provided by the administrators. Users can search and filter the
library, continue reading from the exact sentence where they stopped, mark favorite
passages, group items into collections, and move between chapters of books. Administrator
books are available in PDF and EPUB format and can be read online or downloaded for
offline reading. Books that are not downloaded require an internet connection. Books are
limited to titles that are in the public domain or that the administrators are licensed to
distribute, and books protected by digital rights management cannot be opened. The
application reads only the text of books and does not interpret page layout. Because
books are supplied by the administrators, the number and variety of titles depends on what
has been uploaded to the web application.

**Add (Maglarawan):**
The application can also describe pictures through a feature called Maglarawan. Without
internet, the application gives only general labels of what is in the picture (for
example, "table", "food", or "person"), identified on the device, and it reads any text
found in the picture. A detailed description requires an internet connection: with the
user's consent, the picture is resized and sent to the web-based application, which
requests the description from Google's Gemini service. The description is an estimate that
may be incomplete or wrong, the application does not identify people, and users are
reminded to confirm important items, such as medicines or money, with a trusted person.
Descriptions of the pictures inside EPUB books are not included in this study.

**Add (data storage and accounts):**
Accounts are created and stored first on the device, so that registration works offline.
Because the email address cannot be verified without a connection, the application checks
only its format. Saving data across devices requires a connection to the web-based
application. The documents that users scan or upload remain on the device and are not sent
to the web application; only the administrator books, reading progress, favorites, and
collections are intended to be synchronized to a user's account. Guest data is stored only
on the device and is not synchronized; if a guest registers, the data is moved to the new
account, but a guest who removes the application or clears its data loses it. Password
recovery relies on a security question or on the administrator, and repeated failed log-in
attempts temporarily lock the account.

**Replace paragraph 3 (web application):**
The web-based application is intended for authorized administrators. It receives and
stores the reports and feedback submitted from the mobile application, generates usage,
usability, and user feedback reports, and summarizes report data using the Gemini API.
Administrators can export the reports in PDF, Excel, and CSV formats and send them by
email. The web-based application also manages user accounts, system settings, and the
books offered to the mobile application, and relays image-description requests to the
Gemini API. It does not perform OCR, speech recognition, gesture recognition, or TTS.

**Replace paragraph 4 (evaluation), choose one WER sentence:**
The system will be evaluated by ten (10) visually impaired residents of Bataan. The System
Usability Scale (SUS) will measure perceived usability, a supplementary Likert-scale
questionnaire will gather user feedback, and Word Error Rate (WER) will measure the
accuracy of **[voice command recognition / the text-to-speech output]**.

**Add (device-dependent features):**
The performance of the mobile application depends on the device, including the Android
version (Android 7.0 or higher is required), the installed language packs, and the
availability of offline speech recognition and text-to-speech voices. The Filipino and
English voices and speech recognition packs come from the phone and are not included in
the application; if a language pack is missing, the application can only guide the user
to install it. Voice commands may not work offline on devices without an offline speech
pack.

**Replace paragraph on OCR limits:**
OCR accuracy may decrease when text is blurred, low-contrast, poorly lit, handwritten,
or highly stylized. The text recognizer reads Latin-script text only, so the application
supports English and Filipino text only. The system extracts visible text and reads it in
the order produced by the recognizer; it does not interpret the meaning or layout of
complex documents, and text in several columns, tables, forms, or receipts may be read in
a different order than intended. Scanned PDF pages are read by OCR and are therefore
subject to the same limits. Word documents are supported in the .docx format only, and the
text in their pictures or text boxes may not be read.

**Replace paragraph on navigation limits:** *(unchanged in meaning, add)*
...Gesture navigation is limited to a predefined set of touch gestures, and voice
navigation is limited to a predefined set of commands in Filipino and English. Voice
recognition may be affected by background noise, microphone quality, and pronunciation,
and the application may mistake similar-sounding words. The system is not a general-purpose
virtual assistant.

**Replace paragraph on internet use (web application):**
The mobile application can be used without internet for its core reading functions. An
internet connection is required for downloading or reading administrator books online,
detailed image descriptions, sending reports and feedback, and synchronization. The web
application requires an internet connection for receiving reports, AI summarization,
image descriptions, and emailing. Reports include only the data submitted from the mobile
application. The accuracy and completeness of the AI-generated summaries and descriptions
depend on the AI service used and on the quality of the data, so administrators should
review summaries before sharing them.

**Keep as is (final paragraph):** The evaluation is limited to ten (10) visually impaired
residents of Bataan and may not represent all visually impaired individuals in Bataan or
other regions. The study does not cover specialized hardware such as smart glasses or
dedicated scanners, does not include iOS devices, and is not intended to replace human
assistance or existing government and disability services.

---

## 7. Questions for the Team

1. **Report, feedback and SUS modules (Phase 7):** will they be built before the
   evaluation? In the app they are not built, only the database tables exist. Objectives
   1.h and the web items depend on this.
2. **Web app:** which of the web items in Section 4 (items 2.a to 2.h) already exist? In
   particular book management, the image-description relay and the report endpoints, which
   are not all in `docs/api-contract.md`.
3. **WER:** voice command recognition (Version A) or TTS output (Version B)? The in-app
   WER calculation (Phase 6D) is not built; will it be built, or will WER be computed
   outside the app?
4. **Usage logs:** does the study need them (the table exists, nothing is recorded)? If
   yes, say what they should record and for what purpose.
5. **Likert questionnaire:** is it answered inside the app (not built) or on paper or
   another form? The code has no Likert feature.
6. **Library sync and account sync:** will they be built before the evaluation, or does
   the study say that data is saved only on the device? The current text says "intended to
   be synchronized", which is accurate only if Phase 7 is completed.
7. **Books:** where will the public-domain or licensed books come from and who is
   responsible for the license check? The app's current sample books are original retellings
   of public-domain fables, made only for testing.
8. **Screen reader:** the database allows an input mode of "talkback", but the app has no
   specific TalkBack support beyond standard Android accessibility labels. Should the
   study mention TalkBack at all?
9. **Hardware:** the app needs Android 7.0 or higher (`minSdk` 24). Do you want to state a
   tested device (the target tablet) in the hardware requirements?
10. **Mobile objectives that were not verified on a device:** the Library (Part A),
    PDF text reading and downloading of books have been tested only with test doubles.
    Please do not describe them as validated until the tablet test is finished.
11. **Unused packages:** `csv` and `share_plus` are declared but no current feature uses
    them; they are left out of the requirements. Tell me if they are meant for the
    Phase 7 reports.
12. **Accounts:** the objectives say users "store their information"; the app stores first
    name, last name, email, a password hash and a security-question answer hash. Check
    that this matches the data-privacy statement of the study (Data Privacy Act).
