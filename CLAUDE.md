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
- **Phase 6C — Maglarawan (image recognition): ✅ built 2026-10-04, awaiting review.**
  Offline labels + OCR text check, optional detailed description via the web app (mocked),
  consent, Description screen, History type "Larawan". 361 tests pass. Checklist:
  `docs/testing/phase-6c-checklist.md`. Spec: `docs/specs/image-recognition.md`. Existing
  command matcher, camera guidance and OCR logic unchanged.
- Phase 6D — Core Algorithms (Levenshtein/WER, Laplacian variance, Otsu): ⏸ postponed
  (`docs/specs/algorithms.md`).
- Phases 7 (reports, SUS, sync) and 8 (evaluation, polish): ⏸ postponed.

## Where things are written
- `docs/specs/auth.md`, `profiling.md`, `guest-mode.md`, `navigation.md` — 6B requirements.
- `docs/specs/image-recognition.md`, `algorithms.md` — Phase 6C requirements / postponed 6D requirements.
- `docs/specs/decisions.md` — dated decision log.
- `docs/specs/architecture.md` — how the existing subsystems work (read before changing one).
- `docs/ui/` — mockups. **Mockup layout and wording win** over prompt text.

## Stack
Riverpod 3 (hand-written providers, no codegen) · go_router · sqflite (versioned
migrations, `lib/core/db/migrations.dart`) · ML Kit OCR · speech_to_text · flutter_tts ·
camera · file_picker (SAF, no storage permission) · pdfrx · archive+xml (DOCX) · dio ·
bundled fonts (no google_fonts). minSdk 24, compileSdk 37.0, id `ph.bataan.percipere`.

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
