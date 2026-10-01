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
- Test DB: one in-memory SQLite per test process, wiped per test (`openTestDatabase`).
- Forever-animating widgets (spinner, listening waveform) need manual `pump`s.
- Don't pipe `flutter test` into `head` (aborts the run).
- `flutter_tester` on the dev PC randomly dies (0xC0000005 / "did not complete" /
  "Connection closed before test suite loaded") in any file; rerun. Real failures show an
  assertion.
