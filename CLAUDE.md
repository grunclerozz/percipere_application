# Percipere — project guide for Claude sessions

**Android-only Flutter app** that reads printed/digital text aloud for visually impaired
users in Bataan, Philippines. Used **without seeing the screen**, by **gestures** or
**voice**. Bilingual (**Filipino default**, English), **offline-first**; internet only for
syncing with a separate web admin app (later).

**Work in phases; stop after each for review. Ask before major architectural changes.**

## Current status
- Phases 1–6 and **6B (Registration, Login, Profiling): ✅ done and approved.**
  Tests: `bash tool/test_each.sh`. Since 6B: Reader text size (A−/A+, pinch,
  voice) and the voice listening-loop fix (logging, backoff, fallbacks).
- **Phase 6C — Maglarawan (image recognition): ✅ done, reviewed and approved.**
  Checklist: `docs/testing/phase-6c-checklist.md`. Spec: `docs/specs/image-recognition.md`.
- **Phase 6E — Aklatan (Library): Part A ✅ built 2026-10-06, awaiting the user's tablet test; Part B (describing EPUB images) NOT started — wait for approval.** Two parts: **Part A**
  (Library replaces Reading History, Home screen, details, favorites, collections, progress,
  admin books mocked, PDF + EPUB) is built first; **Part B** (describing images inside EPUB
  books) only after the user has tested and approved Part A. Spec: `docs/specs/library.md`.
- **Voice response time (2026-10-07):** partial-result commands, 1.2 s command pause, 4 s
  dictation, earcon + pulse, listening while reading (barge-in), stale-result discard. Values in
  `lib/config/voice_config.dart`; tablet checklist `docs/testing/voice-response-checklist.md`.
  Awaiting the user's tablet test.
- **Input fix + "questions wait for the answer" (2026-10-07, second round):** single-file
  picking, distinct failure messages, plugin keep rules, build stamp in the log, version
  0.1.1+2; after a question the app waits `VoiceConfig.answerWait` (6 s) before giving
  instructions (`ScreenRegistration.followUp`). Checklist
  `docs/testing/input-fix-checklist.md`. Awaiting the user's tablet test.
- **Percy, the voice assistant (ElevenLabs Agents), 2026-10-07** — since Phase 9 only a
  hidden developer option (off by default): built; online only, the
  app's own voice stays. Spec `docs/specs/assistant.md`, setup
  `docs/setup/elevenlabs-assistant-setup.md` (run `assistant/setup_agent.py`; the user's
  agent `agent_1601m4b0j87se7x8tmtehq4znmas` and voice are built-in defaults in
  `lib/config/env.dart`), checklist `docs/testing/assistant-checklist.md`.
  Awaiting the user's first live test. Also in the tree since 17:23 (undocumented work):
  controls tutorial, natural phrasing, document insights, familiarity.
- **Phase 9 — Percy (self-built): CURRENT (2026-10-10).** Our own intent classifier
  (scikit-learn → `assets/percy/model.json` → pure-Dart inference in `lib/core/percy/`),
  rule-based slots, frame-based dialogue manager, offline; replaces ElevenLabs as default
  (ElevenLabs = hidden developer setting, off). Spec `docs/specs/percy-local.md`; dataset
  `data/percy/intents.csv`; training `scripts/percy/` (README has the commands; Python at
  `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`, venv `scripts/percy/.venv`).
- **Voice latency + speed strip + reading voice (2026-10-10, after Phase 9):** built, awaiting
  the user's tablet test. Checklist `docs/testing/voice-speed-voice-checklist.md`; decision
  log 2026-10-10 (2).
- **Accounts on the web app (2026-10-10, after the speed strip):** login, register with an
  emailed code, password reset by code and suspension checks go to the PHP dashboard
  (`api/v1/`) when built with `API_BASE_URL`; offline login with the copy on the tablet.
  Checklist `docs/testing/server-accounts-checklist.md`; decision log 2026-10-10 (3).
  Awaiting the user's tablet test.
- Phase 6D — Core Algorithms (Levenshtein/WER, Laplacian variance, Otsu): ⏸ after 6E
  (`docs/specs/algorithms.md`); the user approved doing 6E first.
- Phases 7 (reports, SUS, sync) and 8 (evaluation, polish): ⏸ postponed.

## Where things are written
- `docs/specs/auth.md`, `profiling.md`, `guest-mode.md`, `navigation.md` — 6B requirements.
- `docs/specs/image-recognition.md`, `algorithms.md` — Phase 6C requirements / postponed 6D requirements.
- `docs/specs/library.md` — Phase 6E Library (Aklatan) requirements; `docs/api-contract.md` — endpoints the web app must provide (written in 6E).
- `docs/testing/phase-6e-checklist.md` — manual checklist for the Library (Part A).
- `docs/testing/voice-response-checklist.md` — voice response time and barge-in (tablet).
- `docs/testing/input-fix-checklist.md` — document inputs (debug + release APK) and questions waiting for the answer.
- `docs/specs/assistant.md`, `docs/setup/elevenlabs-assistant-setup.md`, `docs/testing/assistant-checklist.md` — Percy, the ElevenLabs voice assistant; `assistant/` — its agent config and Python tools (PC/server only).
- `docs/specs/percy-local.md`, `docs/testing/percy-local-checklist.md`, `data/percy/`, `scripts/percy/` — Phase 9 self-built Percy.
- `docs/testing/voice-speed-voice-checklist.md` — voice cut-offs, speed strip, reading voice.
- `docs/testing/server-accounts-checklist.md` — accounts on the web app (build command, tablet checks).
- `docs/testing/system-test-checklist.md` — general test checklist (inputs, voice, gestures, spamming…); use every round.
- `docs/specs/decisions.md` — dated decision log.
- `docs/specs/architecture.md` — how the existing subsystems work (read before changing one).
- `docs/ui/` — mockups. **Mockup layout and wording win** over prompt text.

## Stack
Riverpod 3 (hand-written providers, no codegen) · go_router · sqflite (versioned
migrations, `lib/core/db/migrations.dart`) · ML Kit OCR · speech_to_text · flutter_tts ·
camera · file_picker (SAF, no storage permission) · pdfrx · archive+xml (DOCX) · dio ·
ElevenLabs Android SDK (voice assistant, Kotlin bridge) ·
bundled fonts (no google_fonts). minSdk 24, compileSdk 37.0, application id `ph.bataan.percipere.app` (was `ph.bataan.percipere` until 2026-10-07; Kotlin package and namespace unchanged).

## Layout
`lib/app` (app, router, bootstrap, theme) · `lib/config` · `lib/core/{accessibility,
gestures, voice, tts, ocr, extraction, db, settings, platform, widgets}` ·
`lib/features/<screen>` · `lib/l10n` (`app_fil.arb` = template).

## Rules
- **Input goes through the CommandBus.** Screens register actions (`AccessibleScreen` /
  `ScreenRegistration`); gestures, voice and taps all resolve to them. Gesture bindings
  live only in `core/gestures/gesture_map.dart`.
- Every screen announces itself; every action gets spoken (+ haptic) confirmation.
- **All strings** (visual and spoken) in ARB files; Filipino first. No ICU plural in the
  Filipino file.
- **All colors/fonts/sizes from the theme** (`AppPalette`, settings) — none hard-coded.
- Touch targets ≥ 56 dp; `Semantics` everywhere; never color alone.
- Heavy work off the UI isolate. Schema changes = **new** migration, never edit old ones.
- Never store or log passwords in plain text.
- `flutter analyze` clean; `///` docs on public classes; tests for logic and screens.

## End-of-phase quality check (required before reporting a phase as done)
Standing rule for the end of every phase, stabilization pass and fix task. Run this check
and include the results in the report. **Don't run the app on the device; the user runs
and tests it themselves.**

1. **Static checks:** run `flutter analyze` and fix every error and warning.
2. **Tests:** run the full test suite (`flutter test`; on this PC `bash tool/test_each.sh`).
   Every test must pass. Add tests for any new feature or fixed bug.
3. **Build:** make sure a release build compiles (`flutter build apk --release`), not
   only debug. (If Gradle says "Unable to establish loopback connection", see Environment.)
   Release builds shrink code (R8) and can break plugins that debug runs and tests never
   exercise: when a phase touches camera, OCR, image labeling, file picking or other
   native plugins, install the release APK on the `Percipere_Light` emulator and try one
   input of each kind (see `docs/specs/decisions.md`, 2026-10-07).
4. **Crash review:** read through all code changed in this phase for possible crashes:
   unhandled exceptions, null values, async errors, `setState` or context use after a
   screen is closed, missing `try/catch` around camera, microphone, TTS, file and
   database calls, and permission denials.
5. **Regression check:** make sure features from earlier phases still work, especially
   voice commands, gestures, back navigation, TTS, the Reader and saved preferences. List
   anything this phase may have affected.
6. **Accessibility check:** every new screen announces itself, every action works by
   voice, gesture and tap, every widget has Semantics labels, and new text follows the
   user's text size, color and theme.
7. **Report:** a short summary with these headings: **Passed**, **Fixed during the
   check**, **Known issues remaining**, and **What I should test manually on the tablet**.

Never report a phase as done while errors, failing tests or known crashes remain, unless
they are listed clearly under "Known issues remaining" with the reason they weren't fixed.

## Environment
- Windows host; project at `D:\Development\Flutter Projects\percipere_app` (quote paths).
- Test on emulator **`Percipere_Light`** (Android 14, Google TTS + speech, host GPU).
  Keep Gradle heap at 4 GB.
- If Gradle says `Unable to establish loopback connection`:
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\tmp\jdk`.
- `flutter_tester` crashes randomly on this PC ("did not complete", 0xC0000005): run
  `bash tool/test_each.sh` (each file alone, crashes retried).
- `percipere/` subfolder = stray old project (excluded). Old prototype backup:
  `..\percipere_app_prototype_backup\`.
