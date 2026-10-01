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
- Turn-taking: speech starting cancels the recognizer; speech ending re-arms it after
  `AppDurations.autoListenDelay`; never listens while reading. Auto-listen in voice mode or
  on `autoListen` screens; stops after `voiceIdleLimit` idle.
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
  (fil/en stop words; Taglish → Filipino), `core/db/daos/documents_dao.dart`.
- `ReaderController`: TTS one sentence per `speak()` (true = finished, false = stopped);
  a token per loop run separates own pause/skip from external interruption (→ pause).
  Auto-saved to history; position saved on pause, every 5 sentences, on close.
  `HistorySource(id)` resumes.

## Settings / History (Phase 6)
- `core/settings/`: `AppSettings` + `SettingsController` (`settingsProvider`), per scope
  (user id or `device`), one preference key per field. Theme/locale/mode/speed/haptics
  providers are views. New setting = field + `PrefKeys` key + row in `setting_items.dart`.
- Settings rows: swipe L/R focus (spoken with value), up/down adjust, double-tap
  cycle/open; TalkBack adjustable semantics need `increasedValue`/`decreasedValue`.
- History: list/search/rename/delete; swipe up = item options; "hanapin X" via
  `onUtterance`; delete confirmed via `bus.offer`.

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
  look kept on the device. `routerProvider` starts at `AppRoutes.home(account)`
  (upgrade for legacy, setup if not completed, else Capture), Welcome, or `/auth`
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
  size in sp: UI scaled by `TextSize.uiScale` (≤ 2×), document text exact
  (`AppTextMetrics`). Theme extensions need value `==` or every rebuild animates.
- `GestureSurface` turns off overscroll effects under it: the Android stretch effect
  crashed `flutter_tester` (0xC0000005) on vertical swipes over a scroll view.
- Reading history is per user (`documents.user_id`); `DocumentsDao.list(userId:)`.
