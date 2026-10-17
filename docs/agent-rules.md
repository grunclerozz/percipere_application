# Agent rules — Percipere (Flutter app)

**The one source of truth for how agents work on this repo.** Claude Code (`CLAUDE.md`) and
OpenAI Codex (`AGENTS.md`) both point here. Change rules **in this file only**.
Project status lives in `docs/handoff/05-current-status.md`; history in `docs/handoff/worklog.md`.

---

## 1. Shared workflow (both agents)

### Before starting a task
1. `git pull` on the branch you will work on (ask the user first if you don't know which).
   Check `git status`: if there are uncommitted changes you didn't make, stop and ask.
2. Read this file, `docs/handoff/05-current-status.md`, and the **latest 3–5 entries** of
   `docs/handoff/worklog.md`.
3. Read the handoff file for the area you will touch (`docs/handoff/01`–`09`) and, before
   changing a subsystem, `docs/specs/architecture.md`.

### While working
- **Only one agent works on a branch at a time.** Before the user switches from Claude Code to
  Codex (or back), the current agent commits its work (even work in progress, with
  `WIP:` in the summary line) and adds a worklog entry saying where it stopped.
- **Work in phases; stop after each for review. Ask before major architectural changes.**
- Ask the user when a requirement is unclear instead of guessing. Mockups in `docs/ui/` win
  over prompt text for layout and wording.

### After finishing a task
1. Run the **quality check** (section 3).
2. Update `docs/handoff/05-current-status.md` (done / in progress / branches / next).
3. Update `docs/handoff/06-known-issues-and-todo.md` if you found, fixed or set aside issues.
4. If a decision was made or changed: add a row to `docs/handoff/07-decisions.md`
   (the long, dated write-up can also go in `docs/specs/decisions.md`, newest first).
5. Add a worklog entry at the **top** of `docs/handoff/worklog.md` (format inside that file).
6. Commit (section 4). Put the commit hash in the worklog entry (a follow-up
   `docs: worklog hash` commit, or amend only if the commit is not pushed and the user agrees).
7. Report to the user (section 8).

---

## 2. Device rule
- **Never run the app on the user's device (the tablet).** The user installs and tests it
  themselves. Don't `adb install` to it, don't `flutter run` on it.
- The emulator **`Percipere_Light`** (Android 14) is allowed, and required for native-plugin
  changes (section 3, step 3).

---

## 3. End-of-phase quality check (required)
Standing rule for the end of every phase, stabilization pass and fix task. Run it and include
the results in the report.

1. **Static checks:** `flutter analyze`; fix every error and warning.
2. **Tests:** full suite. On the dev PC use `bash tool/test_each.sh` (each file alone,
   runner crashes retried); `flutter test` elsewhere. Every test must pass. Add tests for
   every new feature or fixed bug. (Slow/flaky tests: `docs/handoff/08-testing.md`.)
3. **Build:** a release build must compile: `flutter build apk --release`, not only debug.
   Release builds shrink code (R8) and can break plugins that debug runs and tests never use:
   when a phase touches camera, OCR, image labeling, file picking, audio, sherpa-onnx or other
   native plugins, install the release APK on the `Percipere_Light` emulator and try one input
   of each kind (decision 2026-10-07). Don't run tests and a build at the same time.
4. **Crash review:** read all code changed in the phase for unhandled exceptions, null values,
   async errors, `setState` or context use after a screen is closed, missing `try/catch`
   around camera, microphone, TTS, file and database calls, and permission denials.
5. **Regression check:** confirm earlier features still work, especially voice commands,
   gestures, back navigation, TTS, the Reader and saved preferences. List what the phase may
   have affected.
6. **Accessibility check:** every new screen announces itself; every action works by voice,
   gesture and tap; every widget has Semantics labels; new text follows the user's text size,
   color and theme.

**Never report a phase as done while errors, failing tests or known crashes remain**, unless
they are listed under "Known issues remaining" with the reason they weren't fixed.

Docs-only changes: `flutter analyze` is enough (no tests/build needed); say so in the report.

---

## 4. Git
- **Never push to `main`. Never push at all without the user's OK.** Commit only when the user
  asks (or the task says to commit).
- Work on a **branch**, never directly on `main`. Name branches by area:
  `feature/<name>`, `fix/<name>`, `docs/<name>`. The user merges into `main`.
- Commit message: one imperative summary line, feature area first
  (`Voice: …`, `Phase 10: …`, `docs: …`, `Percy: …`), a blank line, then bullet details.
  End with the agent's co-author line if your tool adds one.
- Never commit large model archives (`tool/voice_models/dist/` is git-ignored) or build output.
- Never rewrite published history (force-push, rebase of pushed commits) without the user's OK.

---

## 5. Code rules
- **Input goes through the CommandBus.** Screens register actions (`AccessibleScreen` /
  `ScreenRegistration`); gestures, voice and taps all resolve to the same `A11yAction`s.
  Gesture bindings live **only** in `lib/core/gestures/gesture_map.dart`.
- Every screen announces itself; every action gets spoken (+ haptic) confirmation.
- **All strings** (visual and spoken) in ARB files (`lib/l10n/app_fil.arb` is the template).
  Exceptions: Percy's lines in `assets/percy/responses.json`; voice command phrases in
  `lib/core/voice/voice_commands.dart`.
- **All colors/fonts/sizes from the theme** (`AppPalette`, settings); none hard-coded.
- Touch targets ≥ 56 dp; `Semantics` everywhere; never color alone.
- Fixed layouts, no page scrolling; text size only enlarges the reading text (decisions
  2026-10-01/03). Shared page padding: `PagePadding` (max 640 dp, centered).
- Heavy work off the UI isolate.
- Database: schema changes = a **new** migration in `lib/core/db/migrations.dart`; never edit
  an old one.
- `flutter analyze` clean; `///` docs on public classes; tests for logic and screens.
- Riverpod 3 with hand-written providers (no codegen); go_router for routes.

---

## 6. Privacy, security and content rules
- **No secrets in code or docs**: no passwords, API keys, tokens, SMTP credentials or personal
  data (names, addresses, phone numbers). Build-time values go in `--dart-define`; docs list
  config **names** only (`docs/handoff/09-environment.md`).
- **Passwords:** never stored or logged in plain text (PBKDF2 in the app; server tokens only
  in `flutter_secure_storage`). Never print them in logs, test output or reports.
- **Percy never handles, reads or speaks passwords** (the app and Percy say only the length);
  the Percy analysis panel hides password fields; Percy's log never contains them.
- **Own scanned or uploaded documents stay on the device.** Only admin-book data (progress,
  favorites, collections) is designed to sync. Reports never carry documents, images,
  recordings, passwords or Percy logs.
- Follow the Philippine **Data Privacy Act (RA 10173)**: collect the minimum, say why, ask
  consent before anything leaves the phone (e.g. Maglarawan's online description).
- **Never call Gemini or any other AI API from the app.** Anything that needs an AI service
  goes through the dashboard (server side, its own key). The only legacy exception is the old
  ElevenLabs Percy, reachable only in `PERCIPERE_DEV` builds with its switch on (off by default).
- **Admin books must be public domain or properly licensed.**
- Third-party model licenses matter (MMS Tagalog is CC-BY-NC, eSpeak is GPL-3.0): non-commercial
  thesis use only; review before any public release (`tool/voice_models/README.md`).

---

## 7. Language and UI conventions (Filipino / English)
- Users are blind or low-vision people in Bataan. The app is used **without seeing the screen**.
- **Filipino is the default**, English second. Write Filipino strings first in
  `app_fil.arb`, then English in `app_en.arb`.
- **No ICU plural in the Filipino file.**
- Prompts are short, polite (use "po" as the existing strings do), and avoid words that are
  ambiguous when read aloud (e.g. "Natanggap" instead of "Bukas" for an open ticket).
- Voice phrases: add Filipino and English synonyms (and common Taglish) to the action's
  `voiceSynonyms` or to `voice_commands.dart`.
- Docs, code comments and commit messages are in plain English.

---

## 8. Reporting results to the user
- Plain, short English; file paths for everything; no secrets.
- For any phase or fix, use these headings:
  **Passed** · **Fixed during the check** · **Known issues remaining** ·
  **What I should test manually on the tablet**.
- Say exactly what was run (analyze, which tests, build) and the result. If something was
  skipped or not verified, say so. Mark anything uncertain as **unverified**.
- Mention the branch and commit hash, and whether anything was pushed (normally: not pushed).

---

## 9. Writing docs
- Plain English, short sections, file paths for everything.
- Base docs on the code, `docs/` and git history; don't invent. Mark guesses **unverified**.
- Keep `docs/handoff/` current; it is what the other agent reads.
