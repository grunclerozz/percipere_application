# Decision log

Newest first. **Proposed** = awaiting the user's approval; becomes **Decided** once approved.

## 2026-10-07 (4) — Percy didn't connect: overrides now opt-in
- Two causes: the PC project never received the update (it still matched the 14:20
  upload), and the user's agent doesn't allow overrides — tested against the live agent:
  ElevenLabs connects, then closes with 1008 "Override for field 'first_message' is not
  allowed by config". The same start without overrides is accepted and Percy greets.
- Fix: the app sends language/first message/voice only with
  `--dart-define=ELEVENLABS_USE_OVERRIDES=true` (`AssistantConfig.useOverrides`); by
  default the dashboard's settings are used. Dynamic variables and the user id are still
  sent (accepted by the agent).

## 2026-10-07 (3) — Percy, the voice assistant (ElevenLabs)
**Decided (user):** a Jarvis-like assistant inside the app, built only on ElevenLabs
Agents; public agent for development (private + token service later); Free plan while
developing, paid plan before user testing; the app's own offline voice commands stay.
- Built: Android bridge on the ElevenLabs Android SDK 0.12.2; Dart controller, 12 client
  tools answered through the command bus (Percy can do only what the user can), spoken
  first-use consent, hand-over to the app's own voice for reading/camera/picker, app
  prompts muted (shown) during calls, any user gesture ends the call. Spec:
  `docs/specs/assistant.md`; setup: `docs/setup/elevenlabs-assistant-setup.md`;
  checklist: `docs/testing/assistant-checklist.md`.
- Two-finger swipe left (unassigned until now) calls Percy; the tutorial claims it while
  practising.
- Python on the PC only: `assistant/setup_agent.py` configures the agent (tools,
  instructions, Tagalog + English, voice `EST9Ui6982FZPSi7gCHi`, 5-min/30-a-day limits,
  overrides); `assistant/server/token_server.py` for a private agent.
- The SDK's LiveKit needs JitPack (scoped to `com.github.davidliu`); the APK grew from
  ~147 MB to ~185 MB (WebRTC); `--split-per-abi` gives ~1/4 per phone type.
- The user's agent `agent_1601m4b0j87se7x8tmtehq4znmas` and voice `EST9Ui6982FZPSi7gCHi`
  are the built-in defaults (also in `setup_agent.py`).
- Not verified against the real service in this session (no key, no device): the first
  live test is the user's.
- **Found in the project:** "smarter" features (controls tutorial, natural phrasing
  `core/voice/understanding.dart`, document insights, familiarity) added 2026-10-07
  17:23–17:40 without a decision-log entry. Kept unchanged except: the tutorial now also
  claims the assistant gesture, and the test "ordinary text gets no guessed kind" now uses
  a story (its letter sample was rightly classified as a letter).

## 2026-10-07 (2) — Inputs still failing on the tablet; questions wait for the answer
**Bug report (user):** every input (image, PDF, DOCX upload and camera) ends with "Hindi
mabuksan ang file na ito" / "Walang napiling file", on several devices.
- **Finding:** those two messages are exactly what the code said *before* the first
  2026-10-07 fix (picker errors → "Walang napiling file", every extraction error →
  "Hindi mabuksan…"). With the current code a picker error says "Hindi ko makuha ang file
  na pinili mo" and an OCR failure says "Hindi gumana ang pagbasa ng teksto…". Most likely
  the tablets run an APK from before that fix — easy to happen because the application id
  changed the same day (`ph.bataan.percipere` → `ph.bataan.percipere.app`): the new APK
  installs **next to** the old one instead of replacing it, both called "Percipere". Not
  reproduced on a device here (no emulator in this session); the release APK was built and
  R8's output inspected instead.
- **Real problems still found and fixed:**
  1. The picker allowed multiple selection. Android's plugin then leaves out a file it
     fails to copy and returns an empty list — which the app reported as "Walang napiling
     file" even though a file was chosen. Now one file is picked (`FilePicker.pickFile`), so
     that failure arrives as an error (`PickFailed`); a `content://`-only answer is read by
     bytes; a missing or empty copy is a failure, never "cancelled".
  2. Any unexpected error after picking still said "Maaaring sira ito". New
     `ExtractionFailure.failed` → "Nagkaproblema habang binabasa ko ang file. Malamang hindi
     ito sira." (`readerExtractFailed`); storage errors → `missing`/`unreadable`; DOCX parse
     errors log why; Library-load errors are no longer called a damaged file.
  3. Startup logs `[CAPTURE] app <package> <version> (release build)` so a tablet log shows
     which APK ran. Version bumped to 0.1.1+2 (visible in Android Settings → Apps).
  4. Keep rules added for the native plugins of the inputs (file_picker, image_picker,
     camera/CameraX, flutter_tts, speech_to_text, ML Kit plugin classes, JNI); shrinking
     stays on. Checked in the shrunk APK's mapping: those classes keep their names.
     `test/android_release_rules_test.dart` guards them and that shrinking isn't disabled.
- **Tests:** `test/features/upload/document_picker_test.dart` (system-picker answers →
  file), and `capture_regression_test.dart` now also runs uploads through the real picker
  code (content:// image, cached PDF, content:// DOCX) to the Library and the Reader.

**Questions wait for the answer (user request):** "the voice shouldn't be continuous; when
asking a question it should wait for the answer first before proceeding with the next
instructions."
- After a question the app stops (question + its options/context), listens, and gives the
  instructions after it (how to answer, mode hint, help, side notes such as the Maglarawan
  line on Capture, queued notices) only if no answer comes within `VoiceConfig.answerWait`
  = **6 s** (tunable). Any answer — voice, gesture, tap — drops them. See architecture.md.
- Instructions moved out of prompts into `followUp`: Welcome hints, every Setup step's
  "how" (values like "Laki ng teksto: 18" stay with the question), the Setup summary,
  Capture's Maglarawan line, the Reader's retake offer, the collection picker.
- Offer answers stay valid 20 s + the 6 s wait.

## 2026-10-07 — Every document input failed in the release APK (bug fix)
- **Root cause:** R8 full mode (default with AGP 9) stripped members of Google ML Kit's
  internal classes that ML Kit reads by reflection. In the release APK every OCR call threw
  `NullPointerException … Object.getClass() on a null object reference` (in
  `com.google.android.gms.internal.mlkit_vision_common`), so camera scans, image uploads
  and scanned PDF pages all failed. Debug runs and `flutter test` don't shrink, so nothing
  caught it. The extractor turned every exception into "Hindi mabuksan ang file na ito",
  which hid the real error.
- **Fix:** keep rules for `com.google.mlkit.**`, `com.google.android.gms.internal.mlkit_**`,
  `com.google.android.gms.vision.**`, `com.google.android.odml.**` in
  `android/app/proguard-rules.pro` (shrinking stays on). Reproduced and verified on the
  `Percipere_Light` emulator with the release APK: image, PDF, DOCX, camera and Maglarawan
  all work. `test/android_release_rules_test.dart` fails if the rules are removed.
- **Separate messages:** picker errors / a chosen file that can't be copied → `PickFailed`
  ("Hindi ko makuha ang file na pinili mo"), no longer "Walang napiling file"; a missing
  file → `ExtractionFailure.missing`; an OCR engine failure → `ocrUnavailable` ("Hindi
  gumana ang pagbasa ng teksto… Hindi sira ang file"); a Library save failure keeps the
  text readable and says it wasn't saved. All logged with `[CAPTURE]` and stack traces.
- A picked file with only a `content://` address is read by bytes into the cache; the kind
  comes from the file name.

## 2026-10-07 — Voice response time (user request)
**Decided (user)**: target under 1 s from the end of a spoken command to its action; act on
partial results; short pause for commands, long for dictation (tunable); earcon + pulse the
moment a command is heard; listen while reading (barge-in) with a self-voice filter and only
reading commands; discard stale results; one command per phrase.
**Implemented**
- Cause of the delay: command sessions used `pauseFor` 4 s (the plugin waits that long
  after the last word before stopping), then up to 2 s more for the final result.
- `config/voice_config.dart` holds every value: command pause 1.2 s, dictation 4 s, final
  timeout 0.8 s, partial thresholds 0.9 / 0.8 (×2), gaps 450 ms after speech and 200 ms
  after silence, barge-in start 300 ms, echo filter thresholds. `AppDurations.autoListenDelay`
  moved there as `afterSpeechGap`.
- "Makinig habang nagbabasa" (`listenWhileReading`) is a setting from the start, on by
  default, because false triggers from the tablet speaker can't be ruled out before the
  device test; Reader help recommends earphones.
- Two commands in one phrase now run the first one (before: asked "Ang ibig mo bang
  sabihin…?").
- `error_busy` no longer steps down the recognizer fallback ladder (it only backs off), so
  the shorter gaps can't switch the app to online recognition.
- Fix after the first tablet test: the plugin counts the pause from the start of listening,
  so a 1.2 s pause ended every session before the user began; those quick endings counted
  as recognizer failures and listening gave up. Sessions now wait `waitForSpeech` (4 s) for
  the first words, then switch to the 1.2 s pause (`changePauseFor`).
- Partial results are not acted on in forms, profiling and the legacy PIN screen (their
  `onUtterance` reads free text); they still get the 1.2 s pause. Dictation keeps 4 s.

## 2026-10-06 — Phase 6E = Aklatan (Library); 6D stays postponed (user)
**Decided (user)**
- Next phase is **6E: Aklatan (Library)**, in two parts. Part A first; Part B (EPUB image
  descriptions) only after the user has tested Part A.
- The Library **fully replaces Reading History**; all history entries migrate with no data
  loss, then the History screen and code are removed. "kasaysayan"/"history" open the Library.
- New **Home** screen (Magbasa ng bago / Aklatan) is where login, profiling and guest mode
  lead; Back from Capture and Library returns to Home; "home"/"simula" go there from anywhere.
- Own scanned/uploaded documents **stay on the device** (privacy); only admin-book data
  (book list, progress, favorites, collection links) is designed to sync in Phase 7.
- Admin books come from `AdminBookRepository` (mocked, public-domain texts only).
- Phase 6D (algorithms) remains postponed; Phases 7–8 too.

**Decided (user approved the 6E build plan 2026-10-06; 6E goes before 6D)**:
1. Schema v4 adds `library_items`, `library_favorites`, `library_collections`,
   `library_collection_items`; `documents` is renamed `documents_legacy` (kept as a safety
   copy for one release, dropped by a later migration), not dropped in v4.
2. Own-document text stays in the database (`text_ref = 'db'`), book text goes to files in
   private storage (`text_ref = 'file:<path>'`), so migrated history needs no file moves.
3. Positions are (chapter, sentence). Migrated documents are chapter 0 with their old
   sentence index; total sentences are back-filled the first time the Library is opened.
4. EPUB parsed with the `archive` + `xml` packages already in the project (no new package).
5. `AppRoutes.home(account)` is renamed to avoid clashing with the new Home route.
## 2026-10-04 — Phase 6C = Maglarawan only; algorithms postponed to 6D (user)
- Phase 6C is **Maglarawan** (image description). The three hand-written algorithms
  (Levenshtein/WER, Laplacian variance, Otsu) move to a postponed **Phase 6D: Core
  Algorithms** (`algorithms.md`). The existing command matcher, camera guidance and OCR
  stay unchanged; the matcher thresholds are not touched.
- Offline-first: on-device ML Kit image labeling (top 3 labels ≥ 0.7, Filipino map with
  English fallback), then the existing OCR. Detailed description is optional, online only,
  **through the web app** (`POST /api/describe-image`); the app never calls Gemini and
  never holds an API key. Mocked for now behind `ImageDescriptionRepository`.
- First detailed request needs spoken **privacy consent**, saved per user, changeable in
  Settings. Guests can use everything; their requests are flagged anonymous.
- Description screen gets the Reader's text size controls (see 2026-10-03 entry).

## 2026-10-03 — Reader text size on the Document Box, not the Gesture Pad
- Asked to make two-finger swipe up/down the text-size gesture. That would have removed
  previous/next paragraph from the pad, so the user chose instead: **pinch to zoom in the
  Document Box**, plus A−/A+ buttons and voice — the pad's gestures stay unchanged.
  Profiling Step 2 is unchanged too (single-finger swipes + voice).
- Voice listening loop: sessions are logged (`[VOICE …]` in logcat; was `[Voice …]`); restarts wait for the
  previous session to finish, back off (0.4 s → 5 s) after instant failures, step down
  through on-device → online → the phone's default locale, and after 3 identical failures
  stop and say so (`voiceRepeatedError`). Sessions are now `listenFor` 30 s,
  `pauseFor` 4 s (5 s for dictation).


## 2026-10-01 — Review: no overlaps, no page scrolling
- Review finding: screens overlapped or needed scrolling when the text got bigger.
- **The text size setting now enlarges only the reading text** (Reader's Document Box,
  setup preview), at exactly 18–48 sp, inside its box, which scrolls. Buttons, fields
  and all other boxes keep their design size; replaces proposed decision 4 ("all other
  UI text scales by size / 18").
- Text never grows a box: longer text shrinks to fit (Speaking Zone subtitle 3 lines,
  2 on forms; button labels 1 line). Android's own font size applies to UI text up to
  1.3×.
- Long lists (security questions, setup summary, old accounts) scroll inside a fixed
  box; the main button stays visible.
- Setup Steps 2, 3 and 7 follow their mockup: logo, preview box, Speaking Zone,
  Gesture Pad (no value line or Okay button; confirm by double-tap / "okay").
- Capture: Kasaysayan and Mga Setting side by side.
- Login: extra links (fingerprint, forgot password, old account) two per row.
- Fix: "Ulitin ang setup" now gives guests the full setup (was their short one).

## 2026-10-01 — Phase 6B implementation notes
- Step 1 wording follows the mockup ("Paano mo gustong mag-navigate sa app?"), not the
  prompt text; its layout is the `how_do_they_want_to_use` mockup (no Gesture Pad).
- The "can you see text?" question shares number 2 with Text size ("Hakbang 2 ng 10").
  Guests' short setup is numbered 1–4. A registered ex-guest's setup is numbered over
  the steps still to do.
- Dictated passwords are lowercased with spaces removed (recognizers capitalize and
  space words unpredictably); typed passwords are kept exactly.
- A dictated value fills the focused field unless it is *exactly* a command phrase
  ("tapos na", "bumalik", …), so names are never mistaken for commands.
- Lockout also applies to security-answer guesses (own counter per email). Submitting
  while locked clears the password and asks for it again when time is up.
- Skip on Step 1 sets gestures (long-press still opens voice).
- Back on the first setup step offers to log out and return to Welcome; in "Ulitin ang
  setup" it returns to Settings.
- Logout keeps the user's look and voice on the device (low-vision users shouldn't lose
  their text size on the login screen).
- Legacy PIN accounts lose their (unverified) email in the migration and set one when
  upgrading; they then set a security question and do the setup.
- Saying a Settings row's name opens it only for rows that open something (Logout,
  Ulitin ang setup, Fingerprint); values change only by swipe/double-tap.
- ~~UI text scaling is capped at 2× (36 sp); document text goes to 48 sp.~~
  Superseded by the review entry above.
- Tests: one in-memory database per test; `tool/test_each.sh` runs each file and retries
  `flutter_tester` crashes (the overscroll crash above was one real cause).

## 2026-10-01 — Phase 6B planning

**Decided**
- Phase 6 approved and done. Phases 7–8 postponed. Current phase: **6B (Registration,
  Login, Profiling)**.
- Mockups in `docs/ui/` win over prompt wording.
- Name + 4-digit PIN accounts are replaced by email + password.
- Text colors per theme as listed in `profiling.md`; all verified ≥ 7:1 (lowest: Asul
  #0D47A1 on cream, 7.87).

**Decided** — proposed in the 6B plan, all 14 approved by the user on 2026-10-01
1. **Paragraph gestures in the Reader.** Two-finger swipe right becomes "back" everywhere,
   so the Reader's paragraph gestures move: **two-finger swipe down = next paragraph,
   two-finger swipe up = previous paragraph** (two-finger swipe down is no longer "back").
   Two-finger swipe left: unassigned. Voice "susunod/nakaraang talata" unchanged.
2. **Reader taps.** Auto-read off says "Mag-double-tap para simulan ang pagbasa", but today
   double-tap = repeat sentence and tap = play/pause. Proposal: **double-tap = read /
   pause**, **single tap = repeat the current sentence**. (Alternative: double-tap starts
   reading only before the first play, then keeps "repeat".)
3. **Themes: 3 instead of 4.** Cream & Navy, Dark mode with yellow text, Dark mode with
   white text (backgrounds: cream #F8F4EC, black #000000, black #000000). The old
   "Black on white" palette is dropped; saved settings using it fall back to Cream & Navy.
   Text color becomes its own setting (per-theme list); headings, body and document text
   use it.
4. **Text size in sp.** Stored as an absolute size **18–48 sp, step 2**, default 18.
   Document text uses it directly; all other UI text scales by size / 18 (so the default
   looks like today). Replaces the 80–200 % multiplier.
5. **Speed and pitch steps of 0.25** everywhere (profiling, Settings, Reader swipes) —
   was 0.1.
6. **Step 4 "boses sa Ingles o Tagalog" = the app's spoken language** (prompts + UI text,
   like today's "Wika"). The document voice stays automatic (per-document detection),
   still overridable in Settings.
7. **Microphone on Welcome.** Voice must work on Welcome before any mode is chosen, so on
   first launch the app explains, then asks for microphone permission right after the
   Welcome intro. If refused, gestures work and the intro says so.
8. **Mockup screens `login_confirmation` / `register_confirmation`** ("Nais mo bang mag
   login sa iyong account?" with Login + Register buttons). Where they appear in the flow
   isn't stated. Shown **after logging out** (and when the session expires), so the user
   can log back in or register another account.
9. **Register prompt wording.** The mockup's Speaking Zone says "Ano ang iyong palayaw or
   last name?" while the fields are First Name / Last Name. Per-field prompts are used:
   "Ano ang iyong pangalan (first name)?" / "Ano ang iyong apelyido (last name)?" /
   "Ano ang iyong email address?" / "Gumawa ng password na hindi bababa sa 8 titik."
10. **PIN-account migration.** On first launch after the update, a *logged-in* legacy PIN
    account is asked (by voice) to set an email and password, keeping its settings and
    history. Logged-out legacy accounts appear on Login as "Lumang account" and can be
    claimed once with their old PIN, then must set email + password. After claiming, all
    PIN code is removed. (No real users have PIN accounts yet, so a simpler "drop legacy
    accounts" is also acceptable.)
11. **Password hash:** PBKDF2-HMAC-SHA256, 100 000 iterations, 16-byte random salt
    (stronger than the old PIN's SHA-256 × 10 000), run in an isolate.
12. **Security questions** (spoken list, pick by swipe/voice): first pet's name; town of
    birth; mother's maiden name; first school; favorite food.
13. **New packages:** `flutter_secure_storage`, `local_auth`. `local_auth` needs
    `MainActivity` to extend `FlutterFragmentActivity`.
14. **Git:** initialize the repository with a baseline commit of Phases 1–6 *before*
    6B work starts, so 6B is reviewable as a diff; commit again at the end of 6B.

## 2026-09-30 — Phase 6
- Settings are one `AppSettings` model persisted per scope (user id or `device`), one
  preference key per field; theme/locale/mode/speed/haptics providers are views of it.
- Verbosity levels: brief / normal / detailed.
- History options via swipe up; search via "hanapin X".
- Capture got two extra options (Kasaysayan, Mga Setting) as stacked outlined links.
- Test DB: one shared in-memory SQLite per test process, wiped per test.
- Windows `flutter_tester` crashes randomly (0xC0000005) in any file; not our code.

## 2026-09-30 — Phase 5
- Reader reads with TTS directly, one sentence per call; token tells own pause/skip from
  external interruption. Documents auto-saved to history; resume by sentence index.
- Reading waits for a tap / "basahin" after load (no auto-start) — superseded by 6B's
  auto-read setting.
- Taglish documents use the Filipino voice.

## 2026-09-30 — Phase 4
- PDF via `pdfrx` (MIT) instead of Syncfusion (license key).
- Camera auto-capture after 4 clear frames; photos deleted after extraction.
- Filipino ARB strings avoid ICU plural (Filipino "one" covers 2, 3, 5…).

## 2026-09-30 — Phases 1–3
- Riverpod 3 with hand-written providers (no codegen); `go_router`; `sqflite`.
- Fonts bundled (no `google_fonts`). App id `ph.bataan.percipere`, minSdk 24,
  compileSdk 37.0.
- Speaking Zone = the prompt's "InteractionPanel".
- Voice: on-device first, online fallback; mic permission only after a spoken explanation;
  auto-listen pauses after 60 s idle.
- Our navigation-mode enum is `NavMode` (Flutter has `NavigationMode`).
