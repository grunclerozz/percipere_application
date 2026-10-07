# Architecture notes (Phases 1–6)

Detailed implementation notes moved out of CLAUDE.md. Read before touching a subsystem.

## Accessibility core (Phase 2)
- `bootstrap()` (app/bootstrap.dart) opens the DB, loads settings for the logged-in scope,
  starts TTS, checks voices → provider overrides. Router starts on Welcome only if no mode
  is saved.
- `AccessibleScreen` registers a `ScreenRegistration` (actions + intent overrides +
  `onUtterance`) with `ActionRegistry`; `AccessibilityHost` (MaterialApp.builder)
  announces the active screen. `AccessibleScreen(dependencies: …)` swaps the registration
  in place; re-announce and focus reset only when the active screen *id* changes.
- `GestureSurface` → `GestureClassifier` → `gestureMap` → `NavIntent` → `CommandBus`.
  Visual taps call `bus.activate(id)` too. `PillButton` (and other buttons inside a
  surface) claim their pointers so a tap is not also a surface gesture.
- `Announcer` speaks sentence by sentence (subtitle = current sentence); `protect` keeps
  short confirmations from being cut off; TalkBack on → TalkBack announcements. Any prompt
  stops document reading first (`reading` flag).
- `speechLanguageProvider`: Filipino prompts only if a Filipino voice is installed, else
  English (never Filipino text through an English voice).
- `CommandBus.offer()` / ask-back: a pending yes/no accepted by "oo" or a double-tap.

## Voice (Phase 3)
- `core/voice/`: `SpeechInput` (speech_to_text wrapper), `CommandMatcher` (normalize →
  containment (1 + 0.01/word, longer wins) or Levenshtein; ≥0.8 run, 0.6–0.8 ask back),
  `voice_commands.dart` (app-wide fil/en phrases → `NavIntent`, wake words, yes/no),
  `VoiceController` (permission, turn-taking, auto-listen, errors, `dictate()`).
- Matching order: screen action labels (both locales; "A (B)" also yields A and B) and
  `voiceSynonyms`, then app-wide commands.
- Turn-taking: a prompt starting cancels the recognizer; speech ending re-arms it after
  `VoiceConfig.afterSpeechGap` (echo); a session that ended in silence restarts after
  `VoiceConfig.sessionGap`. All timings and thresholds live in `config/voice_config.dart`.
- Pauses: commands end after `VoiceConfig.commandPause` (1.2 s) of silence, dictation after
  `dictationPause` (4 s). The plugin's final-result wait is `finalTimeout` (0.8 s).
- Partial results: `CommandBus.judgePartial` checks whether a partial result is already a
  whole command (whole-utterance similarity; pending yes/no, then screen actions, then
  app-wide). ≥ 0.9 runs at once; ≥ 0.8 runs when the same command matched twice in a row.
  It waits when a different, longer command starts the same way ("susunod" → "susunod na
  talata") or the words begin a free-text command (`ScreenRegistration.freeTextPrefixes`;
  screens with `onUtterance` and no list never act early). Running goes through
  `handleUtterance`, as for final results; the session is then cancelled and its later
  results are stale (session id), so nothing runs twice.
- One command per phrase: among phrases found word for word, the one said first wins
  (`Matched.at`), also across screen actions and app-wide commands.
- Stale results: any command (voice, gesture, tap) calls `VoiceController.commandExecuted`;
  results from a session that began before it are discarded, and a session open during a
  gesture is restarted.
- Feedback: the moment a phrase is handed to the bus, `Earcon.heard()` (Android
  `ToneGenerator`, channel `ph.bataan.percipere/sound`) and `Haptics.heard()` (25 ms).
- Barge-in: in voice mode with Settings "Makinig habang nagbabasa" on
  (`listenWhileReading`, default on), the mic stays open while the Reader reads. The Reader
  records each sentence (`Announcer.noteReadAloud`); `BargeIn` removes words of the
  sentences read during the session (fuzzy ≥ 0.8 for words of 4+ letters) and accepts only
  `readingControlIntents` (pause, stop, back, faster, slower, bigger, smaller, favorite,
  repeat) at ≥ 0.9; everything else is dropped silently. Prompts still never overlap
  listening. Long-press always stops speech, closes any open session and listens at once.
- Logs: `[VOICE <time> s<session> +ms]` for each step (speech started by mic level, every
  partial/final result, MATCH, ACTION) and one `[VOICE TIMING]` line per command with the
  gaps and **END OF SPEECH→ACTION**.
- Auto-listen in voice mode or on `autoListen` screens; stops after `voiceIdleLimit` idle
  (reading counts as activity).
- On-device recognition first; `error_language_unavailable` → online; no network → explain
  + offer Voice input settings. Mic permission only after a spoken explanation.

## Capture & extraction (Phase 4)
- `core/ocr/`: ML Kit OCR, `text_cleanup.dart` (`cleanText`, `assessQuality`). Big texts in
  `Isolate.run`.
- `core/extraction/`: image → OCR; DOCX → archive+xml; PDF → pdfrx text layer, pages with
  < 20 chars rendered at 2× and OCR'd. Errors → `ExtractionException`.
- `features/camera/`: `CameraSession` (NV21 frames → ML Kit → `FrameStats`),
  `GuidanceTracker` (debounced hints, auto-capture after 4 ready frames).
- Upload via `file_picker` (SAF), no storage permission. Permissions via
  `core/platform/permissions.dart`, always after a spoken explanation.

## Reader (Phase 5)
- `core/tts/chunker.dart` (sentences with exact offsets), `language_detector.dart`
  (fil/en stop words; Taglish → Filipino), `core/db/daos/library_dao.dart`.
- `ReaderController`: TTS one sentence per `speak()` (true = finished, false = stopped);
  a token per loop run separates own pause/skip from external interruption (→ pause).
  Auto-saved to the Library as soon as the text is extracted; the position (chapter +
  sentence) is saved on pause, every 5 sentences, on close. `ItemSource(id)` resumes
  (or opens at a chapter/sentence for a favorite). Chapters come from `ChapteredText`.
  Finished = last sentence read: `finished` + "Tapos mo nang basahin …".

## Settings (Phase 6)
- `core/settings/`: `AppSettings` + `SettingsController` (`settingsProvider`), per scope
  (user id or `device`), one preference key per field. Theme/locale/mode/speed/haptics
  providers are views. New setting = field + `PrefKeys` key + row in `setting_items.dart`.
- Settings rows: swipe L/R focus (spoken with value), up/down adjust, double-tap
  cycle/open; TalkBack adjustable semantics need `increasedValue`/`decreasedValue`.
- (Reading History was replaced by the Library in Phase 6E.)

## Testing
- `test/helpers/fakes.dart` (`TestEnv`, `FakeTts`, `FakeSpeechInput`, `FakePermissions`, …);
  widget tests create envs with `createEnv(tester)` (real clock).
- Test DB: a fresh in-memory SQLite per test, never closed (`openTestDatabase`).
- Forever-animating widgets (spinner, listening waveform) need manual `pump`s.
- Don't pipe `flutter test` into `head` (aborts the run).
- `flutter_tester` on the dev PC randomly dies (0xC0000005 / "did not complete" /
  "Connection closed before test suite loaded") in any file; rerun. Real failures show an
  assertion. `bash tool/test_each.sh` runs each file alone and retries only crashes.

## Accounts, setup, back (Phase 6B)
- `core/auth/`: `PasswordHasher` (PBKDF2-HMAC-SHA256, 100 000 iterations, 16-byte salt,
  `Isolate.run`; iterations stored in `users.secret_kind`), `AccountRepository`
  (register, verify, security answer, guest, legacy PIN claim/upgrade, guest → account
  migration), `LoginThrottle` (lockout per email in `login_attempts`), `SessionStore`
  (`flutter_secure_storage`: logged-in id + fingerprint id), `Biometrics` (`local_auth`,
  biometric only), `AccountSyncRepository` (mock: queues ids, sends nothing),
  `CurrentAccount` (`currentAccountProvider`: login/logout/guest/completeRegistration,
  switches the settings scope), `GuestReminders`.
- `bootstrap()` → `restoreSession()`: secure-storage session (or the old
  `account.currentUser` pref, moved once); "stay logged in" off → logged out at launch,
  look kept on the device. `routerProvider` starts at `AppRoutes.landing(account)`
  (upgrade for legacy, setup if not completed, else Home), Welcome, or `/auth`
  (expired).
- `features/auth/voice_form.dart`: `VoiceForm` — fields are focusable actions; any
  non-command utterance fills the focused field (exact command phrases win), read back
  (passwords only by length; `VoiceController.sensitive` hides recognized words).
  Double-tap / "submit" / "tapos na" submits; long-press dictates the field.
- `features/setup/`: `SetupFlow` (pure: plan per guest/redo/done steps, skip hidden
  sight steps, back, resume, jump from summary) + `ProfilingScreen` (one registration
  per step, id `setup.<step>`, so each step announces itself; values saved live through
  `SettingsController`; progress in prefs `setup.step` / `setup.done` / `setup.seesText`).
- Back: `NavIntent.back` ← two-finger swipe right, voice, and Android back
  (`PopScope` in `AccessibleScreen`). `CommandBus.back()` asks first when
  `hasUnsavedInput`, runs `beforeBack`, announces "Bumalik sa …", and on the first
  screen offers to close the app (`appCloserProvider`).
- Themes: `config/palette.dart` (`ThemeId`, `TextColors`), `AppPalette.withTextColor`;
  `AppSettings.withTheme` applies the "unavailable color → theme default" rule. Text
  size in sp sets only the reading text (Document Box, setup preview), shown at
  exactly that size (`AppTextMetrics`, `AppTheme.documentTextScaler`) inside a
  box that scrolls. UI text keeps its design size; Android's font size is
  capped at 1.3× for it (`UiTextScale`). Theme extensions need value `==` or
  every rebuild animates.
- Fixed layout (review, 2026-10-01): text never grows a box. `FitText` keeps a
  fixed number of lines and shrinks longer text (Speaking Zone subtitle: 3
  lines, 2 on forms; button labels: 1 line). Long lists (`BoxedList`: security
  questions, setup summary, old accounts) scroll inside a bordered box.
  `test/features/screens_fit_test.dart` checks every screen at 360 × 800 dp
  with the system bars and text size 48: no page scrolling.
- `GestureSurface` turns off overscroll effects under it: the Android stretch effect
  crashed `flutter_tester` (0xC0000005) on vertical swipes over a scroll view.
- The Library is per user (`library_items.user_id`); `LibraryDao.list(userId)`.

## Maglarawan — image description (Phase 6C)
- `core/describe/`: `ImageLabelerService` (ML Kit base model, offline) → `pickLabels`
  (≥ 0.7, top 3) → `offlineDescription` (Filipino via `config/image_labels_fil.dart`,
  English fallback, always "Mukhang…", + the Paalala for medicine/money labels).
  `ImagePrep` (isolate): `resizeToJpeg` (≤ 1600 px for upload, 320 px thumbnails).
- `core/network/image_description_repository.dart`: the web app boundary
  (`POST /api/describe-image`, see `docs/api-contract.md`); mock while `USE_MOCK_API`.
  `connectivity.dart`: `isOnlineProvider`. The app never calls Gemini.
- `features/describe/`: `DescribeController` (family by `DescribeSubject`: `NewImage` or
  `SavedDescription`) runs labels + the existing OCR together, speaks the description,
  then `CommandBus.offer`s (text found → Reader; detail when online). `offer` now takes
  `onDecline` so the offers chain. Consent is `AppSettings.describeConsent`
  (ask/allowed/declined; per user; Settings row). `DescribeSourceScreen` picks camera or
  upload; the camera takes `CameraScreen(forDescription: true)` (route `extra: true`).
- `DocumentBox(header:, onTextSize:)`: the thumbnail scrolls with the text; the same
  pinch/A−/A+ text size as the Reader.
- Database v3 rebuilt `documents` to allow `source_type = 'description'` and added
  `thumbnail_path`; v4 moved those rows to `library_items` (`source = 'description'`).
  The Library opens them on the Description screen.
- Capture: third action `capture.describe`; `DescribeIntroOnEntry` reads the full
  explanation once per user (`describe.introSeen`); `onUtterance` answers "ano ang
  maglarawan / paliwanag / explain / tulong" while the button is focused.
- Tests: `TestEnv` fakes (`labeler`, `ocr`, `imagePrep`, `describeRepo`, `online`) and
  marks the intro as already heard unless `describeIntroSeen: false`.

## Aklatan — the Library (Phase 6E, Part A)
Spec: `library.md`; endpoints: `../api-contract.md`.
- **Routes:** `AppRoutes.home` is the base of the back stack; `capture`, `library`,
  `libraryItem`, `favorites`, `chapters` are pushed on top, so Back always returns to Home.
  `_openLibrary()` / `_goAndActivate` in `CommandBus` rebuild `home → screen`.
  `AppRoutes.landing(account)` = upgrade / setup / Home.
- **Data (schema v4):** `library_items` (own documents + one row per user per catalog
  book), `library_favorites`, `library_collections`, `library_collection_items`. Every row
  has a UUID, `synced`, `updated_at`; own documents are `local_only`. `documents_legacy` is
  the renamed old table, kept as a safety copy until a later migration drops it.
  `LibraryDao` leaves text out of list queries; `loadText(item)` reads the DB text (own
  documents, `text_ref = 'db'`) or the JSON text cache (`text_ref = 'file'`, `BookText`).
- **Position:** (chapter index, sentence inside the chapter); `percent` = global sentence
  / `total_sentences`. `ChapteredText` lays chapters out as one string + sentences +
  `chapterStarts`. Migrated history is chapter 0; totals are back-filled when the Library
  or the Reader first opens the item.
- **Books:** `AdminBookRepository` (mock: `sample_books.dart` builds EPUB and PDF bytes),
  `LibraryService` (refresh catalog, read online into the cache, download, remove, update),
  `EpubParser` (container → OPF spine → nav/NCX titles → XHTML paragraphs; records image
  positions in `BookText.images` for Part B; DRM/invalid reported), PDF chapters from the
  outline (`chaptersFromPdf`). Parsing runs off the main thread (`compute`).
- **UI:** `HomeScreen`; `LibraryScreen` (shelves; its own focus: swipe left/right in a
  shelf, up/down between shelves; `LibraryController` holds the lists; `LibraryActions`
  opens/downloads/marks); `ItemDetailsScreen`, `FavoritesScreen`, `ChaptersScreen` reuse
  `BoxedList`. Reader: "Paborito" button in the `DocumentBox` bar, intents `favorite`,
  `favorites`, `nextChapter`, `previousChapter`.
- **Guests:** first download → `guestDownloadWarning` offer (decline continues); one more
  reminder from the Library; `migrateGuest` moves items, favorites and collections.
- **Sync design:** `LibrarySyncRepository` (mock); `LibraryDao.syncBatch(userId)` builds
  what would be sent — admin-book data only.
- **Tests:** `TestEnv` has `books` (mock web app), `storage`, `libraryPaths` (temp dir),
  `bookLoader`; `seedDocument` / `seedBook` in `test/helpers/library_seed.dart`;
  `pumpAppOnCapture` opens Capture from Home.
