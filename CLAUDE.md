# Percipere — project guide for Claude sessions

**Android-only Flutter app** that reads printed/digital text aloud for visually impaired
users in Bataan, Philippines. Used **without seeing the screen**, by **gestures** or
**voice**. Bilingual (**Filipino default**, English), **offline-first**; internet only for
syncing with a separate web admin app (later).

**Work in phases; stop after each for review. Ask before major architectural changes.**

## Current status
- Phases 1–6: ✅ done and approved.
- **Phase 6B — Registration, Login, Profiling: ✅ built 2026-10-01, awaiting review.**
  Email + password accounts (PBKDF2, lockout, security question, fingerprint,
  secure-storage session), PIN accounts migrated, 10-step guided setup, guest mode,
  app-wide back (gesture / voice / Android back), 3 themes + text colors, text size in
  sp, auto-read. 273 tests pass (`bash tool/test_each.sh`). Manual checklist:
  `docs/testing/phase-6b-checklist.md`.
- Phases 7 (reports, SUS, sync) and 8 (evaluation, polish): ⏸ postponed.

## Where things are written
- `docs/specs/auth.md`, `profiling.md`, `guest-mode.md`, `navigation.md` — 6B requirements.
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
