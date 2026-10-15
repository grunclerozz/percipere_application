# AGENTS.md — Percipere (Flutter app)

Read this first. Details live in `docs/handoff/` (links at the end). `CLAUDE.md` is the older
agent guide with the full status history; it is kept and still accurate.

## Project
**Percipere** is an **Android-only** Flutter app that reads printed and digital text aloud for
the visually impaired community of **Bataan, Philippines**. It is used **without seeing the
screen**: every action works by **gesture** (Gesture Pad), by **voice**, and by touch.
Languages: **Filipino (default) and English**. **Offline-first**: scanning, OCR, reading,
gestures, voice commands and Percy work without internet; the internet is only for the web
dashboard (accounts, admin books, reports) and the one-time download of the offline voice
models. Undergraduate thesis project (non-commercial).

The admin web dashboard (PHP/MySQL on XAMPP) is a **separate repo**
(`percipere_web`, folder `percipere_dashboard`). This repo only documents how the app talks
to it: `docs/handoff/04-api-and-dashboard.md`.

## Tech stack (from `pubspec.yaml`, `pubspec.lock`, code)
- Flutter 3.47.5 (stable), Dart 3.13.4 (`environment: sdk ^3.13.4`). App version `0.1.1+2`.
- State: Riverpod 3 (`flutter_riverpod`, hand-written providers, **no codegen**). Routing: `go_router`.
- Storage: `sqflite`, versioned migrations in `lib/core/db/migrations.dart`, **schema version 7**.
  Secrets/tokens: `flutter_secure_storage`.
- OCR: `google_mlkit_text_recognition`; image labels: `google_mlkit_image_labeling`.
- Speech in: `speech_to_text` (Android recognizer) + **sherpa_onnx** (app's own offline command
  recognizer: Whisper tiny Filipino fine-tune + Silero VAD).
- Speech out: `flutter_tts` (Android TTS) + **sherpa_onnx** offline voices (MMS Tagalog, Piper English).
- Files: `file_picker` (SAF, no storage permission), `pdfrx`, `archive` + `xml` (DOCX/EPUB), `camera`.
- Network: `dio`, `connectivity_plus`. Auth: `local_auth` (fingerprint), PBKDF2 password hashing in Dart.
- Percy (assistant): own intent classifier (scikit-learn → `assets/percy/model.json` → pure Dart in
  `lib/core/percy/`). ElevenLabs Android SDK remains only as a hidden developer option.
- Native Kotlin: `android/app/src/main/kotlin/ph/bataan/percipere/` (`MainActivity.kt`,
  `SpeechInfoBridge.kt`, `AudioBridge.kt`, `AssistantBridge.kt`).
- Android: minSdk 24, compileSdk 37, application id `ph.bataan.percipere.app`
  (Kotlin package/namespace still `ph.bataan.percipere`).

## Setup, run, test, build (Windows host; quote paths with spaces)
```bash
flutter pub get
flutter analyze                      # must be clean
bash tool/test_each.sh               # full test suite, one file at a time (see below)
flutter test test/core/voice/        # a folder or single file
```
Run on the emulator (`Percipere_Light`, Android 14), never on the user's tablet:
```bash
flutter run --dart-define=API_BASE_URL=http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard
```
Release APK (the user installs it on the tablet themselves):
```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard
```
- Tablet file: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~94 MB).
- Other build flags (names only): `API_CLEARTEXT_HOSTS`, `USE_ACCOUNT_SERVER`, `USE_MOCK_API`,
  `PERCIPERE_DEV`, `ELEVENLABS_*` — see `lib/config/env.dart` and `docs/handoff/09-environment.md`.
- If Gradle says `Unable to establish loopback connection`, set
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\tmp\jdk`.
- `flutter_tester` crashes at random on the dev PC ("did not complete", 0xC0000005): that is why
  `tool/test_each.sh` runs each file alone and retries crashes. Don't run `flutter test` and
  `flutter build` at the same time (they race on `GeneratedPluginRegistrant.java`).

## Working rules (copied from `CLAUDE.md` and the decision log)
- **Work in phases; stop after each for review. Ask before major architectural changes.**
- **Never run the app on the user's device.** The user installs and tests on the tablet. The
  emulator `Percipere_Light` is allowed (and required for native-plugin changes, see below).
- **Input goes through the CommandBus.** Screens register actions (`AccessibleScreen` /
  `ScreenRegistration`); gestures, voice and taps all resolve to the same actions. Gesture
  bindings live only in `lib/core/gestures/gesture_map.dart`.
- Every screen announces itself; every action gets spoken (+ haptic) confirmation.
- **All strings** (visual and spoken) in ARB files (`lib/l10n/app_fil.arb` is the template,
  Filipino first). No ICU plural in the Filipino file. Exception: Percy's lines in
  `assets/percy/responses.json`; voice command phrases in `lib/core/voice/voice_commands.dart`.
- **All colors/fonts/sizes from the theme** (`AppPalette`, settings). Touch targets ≥ 56 dp;
  `Semantics` everywhere; never color alone.
- Heavy work off the UI isolate. Schema changes = a **new** migration; never edit old ones.
- `flutter analyze` clean; `///` docs on public classes; tests for logic and screens.
- **Privacy and security:**
  - Passwords are never stored or logged in plain text (PBKDF2 in the app, tokens only in secure storage).
  - The app's TTS and **Percy never speak, read or log passwords** (they say only the length).
  - **Own scanned/uploaded documents stay on the device**; only admin-book data is designed to sync.
  - Reports never carry documents, images, recordings, passwords or Percy logs.
  - Follow the Philippine Data Privacy Act (**RA 10173**): collect the minimum, explain why.
  - **No secrets in code or docs** (no passwords, API keys, SMTP credentials, personal data).
- **Never call Gemini or other AI APIs from the app.** The planned detailed image description
  goes through the dashboard (server side). The only existing exception is the old ElevenLabs
  Percy, reachable only in `PERCIPERE_DEV` builds with its switch on (off by default).
- **Admin books must be public domain or properly licensed.**
- **End-of-phase quality check** (required before calling any phase or fix done; report results
  under the headings *Passed*, *Fixed during the check*, *Known issues remaining*, *What I should
  test manually on the tablet*):
  1. `flutter analyze`, fix every error and warning.
  2. Full test suite (`bash tool/test_each.sh`); all must pass; add tests for new features/fixes.
  3. `flutter build apk --release` must compile. When native plugins are touched (camera, OCR,
     image labeling, file picking, audio, sherpa-onnx), install the release APK on the emulator
     and try one input of each kind (R8 can break plugins).
  4. Crash review of all changed code (exceptions, nulls, async, `setState`/context after
     dispose, missing try/catch around camera/mic/TTS/files/DB, permission denials).
  5. Regression check (voice, gestures, back navigation, TTS, Reader, saved preferences).
  6. Accessibility check (announce, voice+gesture+tap, Semantics, theme/text size).
  Never report done while errors, failing tests or known crashes remain, unless they are listed
  under "Known issues remaining" with the reason.
- **Git:** commit only when asked; **never push without the user's OK**. Practice so far: work on
  a branch, not directly on `main`, and let the user merge (current work branch:
  `docs/database-masterlist`; see `docs/handoff/05-current-status.md`). Ask if unsure. Commit messages: one
  imperative summary line (feature area first, e.g. `Voice: …`, `docs: …`, `Phase 10: …`), a
  blank line, then bullet details. Large model archives are never committed
  (`tool/voice_models/dist/` is git-ignored).
- Write docs in plain, short English with file paths. Record decisions in `docs/specs/decisions.md`
  (newest first) and update the status in `docs/handoff/05-current-status.md` and `CLAUDE.md`.

## Where everything else is
- `docs/handoff/01-architecture.md` — folders, modules, CommandBus, routes, state, database.
- `docs/handoff/02-features.md` — every feature, code location, status.
- `docs/handoff/03-voice-and-percy.md` — STT/TTS engines, timings, matcher, Percy.
- `docs/handoff/04-api-and-dashboard.md` — endpoints, auth, books, reports, models, network.
- `docs/handoff/05-current-status.md` — recent work by week, in progress, branches.
- `docs/handoff/06-known-issues-and-todo.md` — open bugs and TODOs with priority.
- `docs/handoff/07-decisions.md` — the important decisions and why.
- `docs/handoff/08-testing.md` — tests, flaky ones, checklists, evaluation instruments.
- `docs/handoff/09-environment.md` — tools, device, adb, config names.
- Deeper sources: `docs/specs/` (specs, `architecture.md`, `decisions.md`), `docs/api-contract.md`,
  `docs/testing/`, `docs/database/`, `docs/features-summary.md`, `tool/voice_models/README.md`,
  `scripts/percy/README.md`.
