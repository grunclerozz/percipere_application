# Decision log

Newest first. **Proposed** = awaiting the user's approval; becomes **Decided** once approved.

## 2026-10-15 — Offline voice with the app's own engines (no Google packs)
**Decided (user request, after 881dd1a still failed offline on the tablet):** offline voice
must work without users installing anything. Android can't install Google's speech packs for
an app, so Percipere downloads its **own** engines once, at first launch (sherpa-onnx).
Scope: offline **voice commands** and **reading aloud / prompts**, Filipino + English. Percy's
free conversation and dictation stay on Android's recognizer (later: `docs/todo.md`).

- **Commands — tried keyword spotting first, rejected on evidence.** sherpa-onnx's
  phone-based KWS (zh-en 3M, 9 MB) with our own Filipino spelling→phone rules found **2 %**
  of Filipino words in real speech (59 Google FLEURS recordings) and ~65 % of clean
  synthetic *English* single words; Vosk has no Tagalog model. **Chosen: Whisper tiny
  fine-tuned for Filipino/Taglish** (`KarlShane11/handsfree-whisper-tiny-tl`, MIT) +
  Silero VAD, run through the **unchanged** command matcher. FLEURS test WER: stock tiny 97 %,
  stock base 64 %, **Filipino tiny 45 %**, Filipino base 37 % (80 MB, 2–3× slower; can
  replace tiny on the server alone). The 80 MB token embedding is stored int8 (43 MB total).
  The VAD cut first syllables ("basahin" → "hina"): each segment is recognized with 0.4 s of
  audio before it. End of speech: 0.7 s of silence (`VoiceConfig.offlineEndOfSpeech`), no
  partial results; commands still run through the matcher and "Ito ba ang ibig mong
  sabihin…?". Order: **app's offline recognizer first for commands (also online)** → the
  Android plan of 2026-10-14 when the model isn't there. The 1.3 s pause, beeps and the
  question stay for the Android path.
- **Voices.** No prebuilt sherpa-onnx Tagalog voice exists: converted Meta **MMS-TTS `tgl`**
  (CC-BY-NC 4.0 — fine for the non-commercial thesis). int8 dynamic quantization made it
  5× slower; instead decoder weights int8 + rest float16, expanded at load (114 → 43 MB, fp32
  speed, near-identical audio). English: **Piper `en_US-ljspeech-medium` int8** (MIT, public
  domain data), eSpeak data reduced to English. Order: an **installed** Android voice →
  the app's voice → Android's (possibly network) voice only as a last resort; a failing
  Android voice is retried with the app's voice. Numbers are spelled in Filipino for the
  Tagalog voice; text is cut into short pieces (first ≤ 70 characters) so speech starts soon.
- **Download.** First launch, before Welcome/tutorial: `OfflineVoiceSetupScreen` (spoken
  wait line, size, every 20 %, "Handa na…"). Server: `GET /api/v1/models` or the static
  `models/manifest.json` (dashboard `models/` folder); fallback: GitHub release
  `voice-models-v1` (also built into the app). Resumable (HTTP Range into `.part`), size +
  SHA-256 checked, free space checked, 4 tries alternating server/GitHub, resumes when the
  connection returns. Total **85.9 MB** download / 108 MB installed.
- **Native:** `AudioBridge.kt` (16 kHz mic stream with the echo canceller; PCM playback).
  Engines run in their own isolates. While the first-launch screen is open the app may speak
  Filipino with Google's network voice (`networkFilipinoProvider`).
- **Emulator check** (release build, `Percipere_Light`, archives served from the PC as the
  dashboard's `models/` folder): manifest → download → SHA-256 → unpack → engines load →
  offline command session (`offline=true`) all work. It found that `tokens.txt` written on
  Windows (CRLF) makes the native reader **end the app**: archives rebuilt with LF, the app
  removes carriage returns from it when unpacking, and a crash guard marks a model broken after two loads that
  never returned (not loaded or downloaded again until "I-download ulit"). Installed models
  are updated only to a higher `version` (or the same version from another file); the
  built-in list never downgrades a newer install.
- APK: the fat release APK grew 186 → 252 MB (ONNX Runtime + sherpa-onnx for three ABIs);
  install the split arm64 APK on the tablet (`flutter build apk --release --split-per-abi`:
  `app-arm64-v8a-release.apk`, 94 MB).
- Known limits: measured on a PC, the emulator and synthetic/FLEURS speech only — the tablet
  test decides (accuracy with real users, speed on the Exynos 1380). Synthetic command test:
  10/18 right + 3 asked. sherpa-onnx's Android library includes eSpeak NG (GPL-3.0): note for
  any public release.

## 2026-10-14 — Voice regression, offline voice, Voice check
**Decided (user request):** voice got slower and missed commands in noise on the Galaxy Tab
S10 Lite, and only worked online. Investigated before changing anything.

- **What changed in the voice path since it felt good** (git, oldest first):
  - `f24085c` (10-07): the 4 s "wait for the user to start" (`waitForSpeech`) was passed to
    `speech_to_text` as `pauseFor`; the plugin also hands it to Android as
    `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` (the silence that *ends* speech), so
    the recognizer itself held results back up to 4 s; `changePauseFor` only shortened the
    plugin's Dart timer. Sessions could last 30 s.
  - `2c42e95` (10-10): `commandPause` 1.2 → 1.0 s (slower speakers cut off mid-command, then
    repeat); cut-off words carried into the next session (in noise this joins noise words to
    the command); "listening" tone when the mic opens; reading pauses for speech; warm-up.
  - `c4b7975` (10-13): prompts and Percy follow the user's speech speed. At "Mabagal" (0.75,
    now offered in the setup) every prompt is a third longer, and the mic only opens after
    the prompt ends (+0.45 s) — the clearest "slow to react" change. Kept (the user asked for
    it); listed for the tablet test.
  - `d8f7eab` (10-13): Percy asks again after 9 s of silence; speaking cancels an open session.
  - Long-standing (baseline): the recognizer locale came from the plugin's list, which on
    Android 13+ holds only the *offline* recognizer's languages — a Filipino user could get
    `en-US` even online. A missing offline pack switched to online recognition for good;
    offline, a network error then stopped listening ("Walang internet…"), offline English was
    never tried. TTS: an engine error never resolved `speak()`, so each failed sentence (e.g. a
    network voice offline) meant 5 s+ of silence; `en-PH` was chosen when merely "available"
    (possibly a network voice). No connectivity check: online sessions offline failed slowly.
  - Most likely causes, in order: (1) prompts at the slower speed + the 4 s silence handed to
    Android (delay); (2) 30 s sessions and carried-over words in noise, whole-phrase-only
    partial matching, English locale for Filipino (missed commands); (3) offline: permanent
    switch to online, no offline English, TTS waits on failed network voices. Not provable
    without the tablet's `[VOICE]` log — the Voice check screen and the checklist confirm it.
- **Offline, plainly.** STT is Android's `SpeechRecognizer` through `speech_to_text`: the
  default recognition service (on the Tab usually Google; Samsung's may be the default —
  Voice check shows which), on-device when `onDevice: true` and the language is installed.
  A Filipino on-device pack is often **not** offered (Google's on-device list is short and
  varies by device/version); Voice check says yes/no from the phone itself and offers the
  download only when the phone lists it. Fallback built: offline English + our bilingual
  matcher (every command has English words) + Percy's classifier (trained on Taglish).
  Alternatives considered: **Vosk** (~50 MB small models, fast, streaming, offline) has no
  ready Filipino model — we'd have to train one; **whisper.cpp** (tiny 75 MB / base 140 MB,
  multilingual incl. Tagalog) has no streaming partials and needs ~1–3 s per command on a
  mid-range tablet, with weak Tagalog accuracy at tiny/base. Not adopted now; revisit only if
  the tablet test shows offline English isn't enough.
- **Fix.** `SttSpeechInput` times silences itself (nothing handed to Android). Commands:
  1.3 s pause, 10 s sessions, judged after 4 s of words at most; Percy 2.2 s / 20 s;
  dictation unchanged. Partial results also run a command said word for word at the *end*
  (twice in a row, not after "hindi/huwag"); final results use the recognizer's second guess
  when it names a command. "Ito ba ang ibig mong sabihin: …?" for unsure matches. Listening
  plan (architecture.md, Voice): offline app language → online → offline English (said once)
  → one spoken message and stop (resumes when the connection is back); network errors switch
  to offline at once; Wi-Fi-without-internet isn't trusted for 60 s. A "stopped" tone when
  listening ends without a command. TTS: errors end the wait at once and skip that voice;
  local voices preferred; `en-PH` only if installed; the Reader retries a failed sentence
  once. Recognizer setup no longer hangs if the plugin's locale query never answers (3 s).
  "buksan ang Aklatan" on screens without an Aklatan row opened the focused item: now the
  Library. Voice check screen (Settings). Module audit: camera open/capture time limits,
  camera hints don't talk over a command being said, Percy's model preloads.
- **Nothing in the voice path waits on the network.** Online recognition is used only when
  the phone has a network and the language isn't installed offline; the network check is a
  local state read in the background. ElevenLabs only in a developer build with its switch.
  Report sync, session check and the Aklatan catalog run in the background.

## 2026-10-13 (2) — Percy stays in the conversation; Percy voice analysis
**Decided (user):** `docs/prompts/revisions.md` items 4 and 7.

- **Item 4 — what broke.** The ElevenLabs path was *not* what spoke: the self-built Percy's own
  end line `dialogue.ended` was "Tapos na po ang usapan natin" ("the conversation has ended"),
  in since Phase 9 (`5db21b0`). It was said whenever `_userEndsPercy` ran, i.e. on **any**
  gesture or tap of the user's while a session was on. That included **long-press** (the app's
  "listen now", which the tutorial teaches as the way to talk), an accidental **single tap**
  (repeat), two-finger double tap (stop speech), and reading commands said over a document
  (barge-in → `VoiceController._handleIntent` → `dispatch`). So reaching for the screen to
  talk to Percy ended it at once. Also since `5db21b0`: a flat 60 s idle end, no reminder.
  ElevenLabs was off by default, but a `percy.elevenLabs = true` saved by a developer build
  stayed in force in a normal build (the switch was hidden, not the setting) — now ignored.
- **Fix.** `CommandBus._keepsPercy`: long-press listens now, single tap repeats Percy's last
  line, two-finger double tap stops speech — the session stays. Other swipes, double-taps and
  button taps still end it ("user takes back control") but with a goodbye. Barge-in commands
  run as Percy's own (`runReadingCommand`). Silence: 9 s (counted from when the app stops
  talking; not while reading, while Percy acts, or while partial words are coming in) → one
  "Nandito pa po ako. Ano po ang maitutulong ko?" (`dialogue.reprompt`, reopens listening even
  after recognizer give-ups) → 9 s more → "Paalam muna po…" (`idle_end`). `dialogue.ended` is
  now "Sige po, paalam! Tawagin lang po ako ulit."; the ElevenLabs `assistantEnded` is "Paalam
  muna kay Percy." Recognizer errors were already retried by the listening loop; now tested.
  ElevenLabs only with `elevenLabsActiveProvider` = developer build **and** the switch.
  Tests: `test/core/percy/percy_session_test.dart`.
- **Item 7(a) — speech engines Percy uses (both on-device, same as the rest of the app).**
  STT: `speech_to_text` (Android `SpeechRecognizer`, Google speech services on the tablet),
  on-device first (`onDevice: true`), locale from the recognizer's list — Filipino UI: `fil-PH`,
  `fil`, `tl-PH`, `en-PH`, `en-US` (first found); English UI: `en-PH`, `en-US`, `fil-PH`.
  Fallbacks: missing offline pack → online recognition; repeated errors → the phone's default
  locale. TTS: `flutter_tts` with the Google engine (`com.google.android.tts`) when installed,
  else the phone's default engine; language `fil-PH` (English `en-PH`/`en-US`), the "reading
  voice" setting's voice, speed `0.5 × readingRate` (engine scale), pitch from Settings. Percy
  has no voice of its own: its lines go `CommandBus.say` → `Announcer` → the same `TtsService`,
  language tag and `readingRate`, so it speaks with the app's voice and speed. Nothing else
  (ElevenLabs only in a developer build with its switch on).
- **Item 7(b) — "Percy analysis" panel.** Developer setting (`percy.analysis`, off; row only in
  `PERCIPERE_DEV` builds). Per sentence: transcript, language (Filipino/English/Taglish from
  the function-word `detectLanguage`, with counts), intent, confidence, top 3, action taken
  (`run:…`, `open:…`, `exact:…`, `asked`, `chat`, …). In memory only (last 20), no audio, no
  database; "•••" on password fields. Shown over every screen inside `IgnorePointer` so it never
  blocks gestures. Tests: `percy_session_test.dart` (data), `percy_analysis_panel_test.dart`.

## 2026-10-13 — Revisions round: tutorial, speech speed, visible password, Percy intro, layout
**Decided (user):** `docs/prompts/revisions.md` items 1, 2, 3, 5, 6 (items 4 and 7 not in this round).

- **Tutorial (1).** Not a removed route: the tutorial was only reachable on the very first launch of
  a device, before Welcome, and the `tutorial.done` flag was device-wide, so a second user or a
  tablet that had already seen/skipped it never saw it again. It now runs after the setup finishes
  (so the navigation mode is already chosen): registered accounts once per account, guests once per
  device (`tutorialSeen`). The pre-Welcome route and `initialTutorialDoneProvider` are gone.
  Replay: Settings, the voice phrases ("tutorial", "turuan mo ako", "paano gamitin") and Home help.
- **Speech speed (2).** Setup step 5 already existed but as a 1.25x stepper; now three named
  options (Mabagal 0.75 / Katamtaman 1.0 / Mabilis 1.5, `SpeechSpeed`) that play a sample on focus.
  The `Announcer` now speaks prompts and Percy at `readingRate` too (before, only the reader and
  the speed changes did), unless a caller passes its own rate.
- **Password visible (3).** Required by the adviser/panel. `VoiceForm.passwordHidden` (default
  visible, reset each time the screen opens), eye button in `VoiceTextField`, a once-per-screen
  spoken notice. The app's TTS and Percy still never speak the password (only "9 titik"); passwords
  are not logged. **TalkBack itself may speak typed characters** — in public, hide the password
  or use earphones.
- **Percy intro (5).** First step of the tutorial; also `IntroRule` ("sino ka", "ano ang kaya mo",
  …) answers with `dialogue.introduction` anytime. The same phrases were added to `intents.csv`
  under `greeting` and Percy was retrained.
- **Layout (6).** One `PagePadding` (32 dp sides, 24 dp top/bottom, content at most 640 dp and
  centered on a tablet) used by `GesturePadLayout`, Welcome, Setup, Tutorial and Camera.
  `test/features/screen_layout_test.dart` checks phone (360x800) and tablet (800x1280) at normal
  and largest text.

## 2026-10-11 (5) — First tablet test: cleartext only to the server, server address, report status
**Decided (user):** write the first-tablet-test guide, lock plain HTTP to the server's host, add a
server address field to the developer settings, and show the dashboard's ticket status.

**Done:**
- **Cleartext HTTP only to the server.** The release APK used to allow plain `http://` to every host
  when built with an `http://` `API_BASE_URL`. Now `android/app/build.gradle.kts` writes
  `res/xml/network_security_config.xml` for the build: cleartext off, except the host of
  `API_BASE_URL` (when it is `http://`) and the hosts in `--dart-define=API_CLEARTEXT_HOSTS=a,b`.
  Checked in the built APK (`aapt2 dump xmltree`): exactly those hosts. **Also enforced in Dart**
  (`CleartextGuard`, `lib/core/network/api_dio.dart`; same rule in `Env.allowsCleartext`), because
  Dart's own HTTP client does not obey Android's network security config, so the XML alone would
  not have stopped the app's requests. https is never blocked.
- **Server address in the developer settings** (`PERCIPERE_DEV=true`): Settings > "Server address
  (developer)" saves an address in the device preferences (`dev.serverAddress`); books, accounts and
  reports follow `serverAddressProvider`, no rebuild needed. A typed `http://` address is refused
  unless its host is allowed by the build (then the message says to use https or rebuild with
  `API_CLEARTEXT_HOSTS`). A normal build ignores any saved address.
- **Ticket status in "Aking mga report"**: `GET /api/v1/reports/{ticket}`; the answer is kept in
  `issue_reports.server_status` (migration v7) and shown instead of "Naipadala":
  Natanggap (open) / Ginagawa (in_progress) / Naayos na (resolved) / Sarado (closed). Asked each time
  the screen opens, for sent reports that are not closed (20 newest); offline keeps the last answer.
  The ticket page right after sending still says "Naipadala".
- `docs/testing/first-tablet-test.md`: merge the PR, update the XAMPP folder, health URL in the
  tablet's browser, build, what to try, and what to do when it fails.

**Why "Natanggap" and not "Bukas" for open:** "Bukas" also means "tomorrow" and "open (a door)";
read aloud to a blind user it is ambiguous. "Natanggap" (received) says what it means.

## 2026-10-11 (4) — Accounts and reports move to the REST URLs
**Decided (user):** after the books, move the app's accounts and reports to the dashboard's REST
routes.

**Done:**
- `HttpAccountApi` calls `auth/register|verify|resend|login|logout|me|password-reset/request|password-reset`.
  A success is the plain resource; a failure is read from `{"error": {code, message, fields, retry_after}}`.
- `HttpIssueReportApi` calls `POST reports`. The body has `type`, `module` and `severity` as `{code, label}`
  and `reporter: {kind, display_name}`; the enums gained their codes (`bug`, `voice_commands`,
  `text_to_speech`, …). Labels stay the English names the dashboard already shows.
- `reporter.display_name` is `null` on purpose: a signed-in report is linked to its account by the token,
  so the name does not need to travel (less personal data on the wire).
- A repeated ticket (200) counts as sent, as the 201 does.

**Needs:** a dashboard with the REST routes (branch `fix/webapp-api` of the dashboard repo, once merged).
The app no longer calls the old `.php` URLs, so against an older dashboard accounts would show a server
error and reports would stay pending.

**Checked** against the real router with `test_live/accounts_reports_live_test.dart` (register, verify, me,
logout, login, wrong password, taken email, forgot and reset, a report sent twice, a linked report, a refused
report, a missing server) and `test_live/books_live_test.dart`.

## 2026-10-11 (3) — Aklatan loads its books from the dashboard
**Decided (user):** once the dashboard's books API works, load Aklatan's admin books from it
and remove the mocks.

**Done:**
- `HttpAdminBookRepository` (dio) reads `GET /api/v1/books` page by page, `GET /books/{id}`
  before a download, `/file` and `/cover`. The Library page of the dashboard is where the
  admins add books (PDF or EPUB, optional cover) and switch them on or off.
- **Removed:** `MockAdminBookRepository` and `sample_books.dart` left `lib/`. The mock lives on as
  `FakeAdminBookRepository` / `SampleBooks` in `test/helpers/` for the existing tests. The spoken
  testing aid "magdagdag ng bagong aklat" is gone from the Library screen.
- **Builds without `API_BASE_URL`** have no admin books (`UnconfiguredBookRepository`, like having
  no internet). There is no mock fallback: it would hide a missing server.
- **Integrity:** a download is written to `<file>.part`, checked against the server's `file_size`
  and `checksum` (SHA-256), then renamed. A mismatch deletes it and counts as a failed download.
- **Removal:** a book an admin switches off is no longer listed; the app treats it as removed (the
  user is told, progress is kept, the book is unavailable), as before.
- **Language:** only `en` (code or name English) selects the English voice; every other language
  reads with the Filipino voice.
- **Not changed:** accounts and reports still use the older `.php` URLs (kept working, deprecated by
  the dashboard); moving them to the REST URLs is a separate step.

## 2026-10-11 (2) — Percy retrained; settings chosen by cross-validation
**Decided (user):** retrain Percy now, and tune by 5-fold cross-validation instead of the validation set.

**Why:** the retrain with the 18 `report_issue` rows (513 sentences, 27 intents) first picked Logistic Regression C=1, balanced, by validation macro F1. Its probabilities were low:
- only 5 of 77 test sentences reached Percy's 0.60 "act" threshold;
- 37 fell under 0.30, where Percy says it didn't understand.

The validation set has 77 sentences, so its winner (0.637 vs 0.604 macro F1) was within noise.

**Change:** `train.py` now tunes both models by stratified 5-fold cross-validation on train + validation (mean macro F1, features refit per fold). The split, features and test set are unchanged.

**Result:** Logistic Regression **C=100, balanced** (CV macro F1 0.621 ± 0.067).
- Test accuracy 0.883, macro F1 0.731.
- 64 of 77 test sentences act directly, 98% of them right.
- `report_issue` 3/3.
- Report: `data/percy/reports/report-2026-10-11.md`.
- `PercyIntent.ruleOnly` is now empty. `ReportIssueRule` stays as a backstop.

**Still weak:** 16 intents have only 7–8 sentences. More team-written sentences remain the biggest improvement.

## 2026-10-11 — Phase 10: Report an Issue
**Decided (user):** a one-question-per-page report flow (spec `report-an-issue.md`).

**The owner's choices:**
- **Endpoint:** extend the dashboard's `api/v1/feedback.php` rather than add a new `/api/reports`. The dashboard got schema v9 (ticket number, source screen), the new modules, the app's field names, and `created_at` for offline reports. A repeated ticket stores nothing new.
- **Second entry point:** a Home link, because the app has no Help screen.

**Implementation:**
- **Database version:** the table is migration **v6**, because v5 already existed (Percy's log).
- **Extra columns:** `user_id`, so "Aking mga report" shows only that account's reports. Reports move with a guest who registers and survive account deletion.
- **No mock server:** without `API_BASE_URL`, reports honestly wait as pending.
- **Sending:** right after "Ipadala", at app start, when the app returns to the front, when the connection returns (`IssueReportSyncHost`), and when "Aking mga report" opens.
  - No connection or a server error leaves the report pending.
  - A refused report is kept as failed; it is never deleted.
- **Voice command:** `NavIntent.report` existed as a "not ready" placeholder; it now opens the flow.
  - Synonyms: "mag-report", "i-report", "report an issue", "may problema", "ulat", and others.
  - "puna" and "feedback" were removed from the synonyms, because they are answers on page 1 (Percy still understands "feedback" in a sentence).
- **Percy:** `PercyIntent.reportIssue` plus 18 Starter rows in `intents.csv`. Per the spec, there is no retrain in this phase: `ReportIssueRule` (a keyword rule) finds it until then.
  - TODO: retrain, then empty `PercyIntent.ruleOnly`.
  - The classifier test now allows exactly the rule-only intents to be missing from the model.
- **Severity for non-bugs:** the app sends `null`. The dashboard's NOT NULL column keeps its `Medium` default, so the dashboard shows Medium for feature requests.

## 2026-10-10 (3) — Accounts on the web app (server login)
**Decided (user):** the app logs in against the PHP/MySQL dashboard (`percipere_dashboard`,
`api/v1/`, its `docs/API.md`), so the thesis can show server accounts.

**User's answers:**
- **Offline login:** allowed for accounts already used on this tablet.
- **Forgot password:** now uses a code emailed by the server (new endpoints `password_forgot.php` and `password_reset.php`).
- **Accounts that existed only on the phone:** moved to the server at their next login.

**Implementation:**
- **On/off switch:** `Env.accountServer` is on when `API_BASE_URL` is set. `USE_ACCOUNT_SERVER=false` brings back accounts kept only on the phone. `USE_MOCK_API` is separate and still controls the Library and Maglarawan mocks.
- **Code layout:**
  - `AccountApi` / `HttpAccountApi` (dio) only talks to the server.
  - `AccountService` keeps the server and the phone in step.
  - Screens use `AccountService`.
- **One local account per server account:**
  - Linked by `users.server_id`; it holds the settings, Library and fingerprint.
  - It is created at the first login; a phone account with the same email is reused.
  - Its password hash is replaced at each server login, so offline login uses the newest password.
- **Sign-in token:** stored in secure storage per local account (`api.token.<id>`), never in SQLite.
- **Logout:** ends the server session without waiting for the network.
- **Login outcomes:**
  - Wrong password: the phone's lockout (30 s, doubling) still counts too, so offline guessing is slowed the same way.
  - Server 429: the server's `retry_after` drives the spoken countdown.
  - Unverified account: a fresh code is sent, then the code screen opens.
  - Phone-only account with the right password: it is registered on the server with the same name and password, then the code screen opens (`NeedsEmailCode.moved`).
  - Suspended or waiting for approval: the reason is spoken.
  - No internet: the copy on the phone is used ("Walang internet…"); an account never used here needs the internet.
- **Registration:**
  - First and last name are sent as one `full_name`; the local account keeps both.
  - New `VerifyEmailScreen`: the 6-digit code, dictated or typed. Filipino, Spanish and English digit words count (`AuthRules.spokenCode`). "ipadala ulit" sends a new code.
  - The security question is skipped for server accounts, because the emailed code replaces it. Fingerprint offer or setup comes next.
- **Forgot password:** new `ResetPasswordScreen`: email → code + new password → logged in. The old security-question screen stays for phone-only mode.
- **SessionGuard:** asks the server (`me.php`) at start, after each login and whenever the app comes back to the front.
  - Suspended: logged out, with "Naka-suspend ang iyong account…".
  - Token no longer valid: the token is forgotten and the phone stays logged in, since nothing else needs the token yet.
- **Plain HTTP:** allowed only when the build's `API_BASE_URL` starts with `http://`. `build.gradle.kts` reads it from the Flutter dart-defines and sets `usesCleartextTraffic`.
- **Not changed:**
  - Guest mode.
  - Old PIN accounts. They still upgrade on the phone, then move to the server at their next login.
  - Library and Maglarawan mocks.
  - Account sync (Phase 7).

## 2026-10-10 (2) — Voice latency, speed strip, reading voice
**Decided (user):** three small additions — faster, more forgiving voice commands; a speed
strip at the right edge of the Gesture Area; a female/male reading voice in Settings.
**Implementation choices:**
- **No rolling audio buffer.** Android's `SpeechRecognizer` (via `speech_to_text`) opens the
  microphone itself and can't be given audio recorded earlier; doing it would need our own
  native recognizer pipeline. Instead the recognizer is created once and reused (prepared on
  the first screen and when the app comes back), and a session cut off mid-speech restarts
  at once and keeps the words heard so far (up to 3 times, then "Pasensya na po, pakiulit.").
  Words followed by a quiet end are acted on instead of dropped.
- The end-of-speech pause is one constant, `VoiceConfig.commandPause`, now 1.0 s.
- The "listening" blip plays when the microphone opens after the app spoke (or on a
  long-press), not on silent restarts, so voice mode doesn't beep constantly.
- Talking over the reading pauses the Reader's voice (TTS can't be ducked mid-sentence);
  without a command the sentence is read again. After a false alarm it won't pause for
  speech again for 8 s, so a misheard echo can't loop the same sentence.
- The latency log (`[VOICE TIMING]`, now with SPEECH START→ACTION) prints in debug builds
  only; the other `[VOICE]` lines are unchanged.
- The speed strip sits **beside** the pad's gesture surface (not on it), so the two can never
  mix. It is on every screen with a Gesture Pad. During reading, the value is spoken between
  sentences and reading resumes at the new speed. The mockup's Volume strip was not in the
  request and isn't built.
- The reading voice is saved as `female` / `male` (or `name:<voice>` when the engine gives no
  gender) and applies to documents and prompts. A gender choice follows the document's
  language when that language has a voice of that gender. Google's voices usually don't name
  their gender, so on many phones the row lists voices by name.

## 2026-10-10 — Phase 9: Percy (self-built) replaces ElevenLabs as the default
**Decided (user):** for the Intelligent Systems class, Percy runs on **our own intent
classifier** (scikit-learn, trained on the team's `data/percy/intents.csv`, exported to JSON,
run in pure Dart), fully offline, no external AI API. ElevenLabs moves behind a hidden
developer setting, off by default. Spec: `percy-local.md`. Build without waiting for plan
approval; stop only on conflicts with existing code.
**Implementation choices (this session):**
- Work continues in the git repository: the latest copy (`percipere_app-main`, incl. the
  dataset) was committed first (`a4d52a1`).
- Python 3.12 is installed but not on PATH (`%LOCALAPPDATA%\Programs\Python\Python312`); the
  training venv is `scripts/percy/.venv` (ignored by git).
- Preprocessing and feature analyzers are hand-written in both languages (accent folding,
  hyphens/apostrophes deleted, wake word dropped, word 1–2-grams, per-word char 3–5-grams)
  instead of scikit-learn's built-in tokenizers, so Dart reproduces them exactly.
- Local Percy is a voice session on the app's own speech (no muting as with ElevenLabs), so
  the screens' own confirmations (delete, logout) are spoken and answered by yes/no through
  Percy — this also closes the "hidden confirmation" gap found in the 2026-10-08 review.
- Percy's spoken lines live in `assets/percy/responses.json` (as the spec asks), an exception
  to the ARB rule; Settings labels stay in the ARB files.
- Developer-only rows (ElevenLabs on/off, export Percy log) appear only in builds with
  `--dart-define=PERCIPERE_DEV=true`.
- The dataset is small and lopsided (58 team rows; 16 intents have 8 examples), so test
  metrics are noisy; the validator warns and the report shows team-only accuracy separately.

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
