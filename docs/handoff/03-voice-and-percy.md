# 03 — Voice and Percy

Sources: `lib/core/voice/`, `lib/core/offline_voice/`, `lib/core/tts/`, `lib/core/percy/`,
`lib/config/voice_config.dart`, `lib/config/percy_config.dart`, `docs/specs/architecture.md`
(Voice section), `docs/specs/percy-local.md`, `docs/specs/decisions.md` (2026-10-07 … 2026-10-15),
`tool/voice_models/README.md`, `scripts/percy/README.md`.

## Speech-to-text (listening)
Entry point: `speechInputProvider` = `HybridSpeechInput` (`lib/core/offline_voice/hybrid_speech_input.dart`),
driven by `VoiceController` (`lib/core/voice/voice_controller.dart`).

**Engine order for commands** (`VoiceController._planNow(commands: true)`):
1. **App's own offline recognizer** when its model is downloaded and loaded — first, online or
   offline. Whisper tiny fine-tuned for Filipino/Taglish (`KarlShane11/handsfree-whisper-tiny-tl`)
   + Silero VAD, run by sherpa-onnx in an isolate (`command_recognizer.dart`), mic audio from
   native `AudioBridge.kt` (16 kHz, echo canceller). Transcript → the normal matcher.
2. Otherwise the Android recognizer (`SttSpeechInput`, `speech_to_text`), plan from 2026-10-14:
   on-device in the app language if installed → online in the app language → offline English
   (Filipino users) → one spoken "can't listen" message.

**Dictation** (names, email, password, titles) and **Percy** always use the Android recognizer,
so they need internet unless Android has an offline language pack.

**Native helpers:** `SpeechInfoBridge.kt` (`ph.bataan.percipere/speech`: recognizer service,
installed offline languages, download request), `AudioBridge.kt` (`ph.bataan.percipere/mic`,
`ph.bataan.percipere/audio`).

## Text-to-speech (speaking)
`ttsServiceProvider` = `HybridTtsService` (`lib/core/offline_voice/hybrid_tts_service.dart`),
created in `bootstrap()`. Order per language:
1. A voice **installed** on the phone (Android TTS via `flutter_tts`, Google engine preferred).
2. The app's own offline voice: Meta **MMS-TTS Tagalog** (`fil`) or **Piper en_US-ljspeech-medium**
   (`en`), sherpa-onnx in an isolate (`offline_speaker.dart`), played by `AudioBridge.kt`.
3. Whatever Android has (possibly a network voice) — last resort. If an Android voice fails
   mid-utterance, the same text is spoken by the offline voice.

Prompt language: `speechLanguageProvider` (`lib/core/tts/speech_language.dart`) uses Filipino
only if a Filipino voice works offline (Android or bundled), else English; during the
first-launch download a network Filipino voice is allowed (`networkFilipinoProvider`).
All prompts follow the user's speech speed (`readingRateProvider`).

## Offline voice models (downloaded once)
| Archive | Download | License |
|---|---|---|
| `percipere-asr-fil-en-v1.tar.gz` (Whisper tiny-tl + Silero VAD) | 33.5 MB | MIT |
| `percipere-tts-tgl-v1.tar.gz` (MMS Tagalog) | 38.4 MB | CC-BY-NC 4.0 (non-commercial) |
| `percipere-tts-en-v1.tar.gz` (Piper English + eSpeak data) | 14.0 MB | MIT / public domain data / GPL-3.0 (eSpeak) |
Total 85.9 MB. Download flow, manifest and resume: `04-api-and-dashboard.md`. Build scripts and
measurements: `tool/voice_models/README.md`.

**Offline status (2026-10-15):** commands and prompts/reading work offline once the models are
installed (verified on PC and the Android emulator; **not yet on the tablet**, and the archives
are **not yet uploaded** to the dashboard or GitHub). Before the download finishes, offline
voice depends on Google packs as before.

## Listening timings (`lib/config/voice_config.dart`)
| Name | Value | Meaning |
|---|---|---|
| `waitForSpeech` | 4 s | wait for the user to start speaking |
| `commandPause` | 1.3 s | silence that ends a command (Android path) |
| `offlineEndOfSpeech` | 0.7 s | silence that ends a command (offline recognizer, VAD) |
| `dictationPause` | 4 s | silence that ends dictation |
| `percyPause` | 2.2 s | silence that ends a sentence to Percy |
| `commandListenFor` / `percyListenFor` / `listenFor` | 10 / 20 / 30 s | longest session |
| `commandSpeechMax` | 4 s | words still changing after this → judge now (noise) |
| `finalTimeout` | 0.8 s | wait for Android's final result after stop |
| `partialAcceptScore` / `partialRepeatScore` | 0.9 / 0.8 | act on partial results |
| `answerWait` | 6 s | after a question, wait before giving instructions |
| `afterSpeechGap` / `sessionGap` | 0.45 / 0.2 s | restart gaps (echo / silence) |
| `recognizerSettle` | 0.3 s | Android recognizer left alone after a stop/cancel before the next session |
| `cueFallback` | 1.5 s | "listening" tone waits for sound from the mic; plays anyway after this |
| `errorAfterDone` | 0.2 s | wait for the error that follows Android's `done` |
| `staleEventWindow` | 1 s | an end/error this soon after the app closed the previous session is stale |
| `deadRecognizerAfter` | 5 | sessions in a row with no mic sound before "voice not working" (busy/client errors) |
| `giveUpGrace` | 1.5 s | "voice not working" waits; a late result cancels it |
| `noisyLevel` / `noisyShare` / `noisyMinReadings` | 4 / 0.5 / 5 | room counts as noisy (level readings before the words) |
| `lowConfidence` | 0.5 | Android confidence below this counts like noise |
| `noisyAskScore` | 0.45 | in noise, commands this similar are asked back (quiet: 0.6) |
| `micNoiseSuppressor` / `micAutoGain` | on / off | phone noise suppressor / AGC on the app's own mic (offline commands) |
Silences on the Android path are timed by the app, never handed to Android (decision 2026-10-14).
Earcons (`ToneGenerator`, channel `ph.bataan.percipere/sound`): "heard", "listening", "stopped".

## Hold to listen (2026-10-16, branch `feat/voice-hold-interrupt`)
(Since 2026-10-17 this is **push-to-talk**, hold time 450 ms: see "Startup loading screen, busy
phases, push-to-talk" below.)
Holding one finger still on the gesture area (`VoiceConfig.holdToListen`, then 650 ms) stops all speech
(prompts, Percy, the Reader) and listens at once: `GestureType.longPress` → `NavIntent.listen` →
`VoiceController.listenNow()`. It already worked this way; this change makes the hold time
configurable in `voice_config.dart`, and:
- **While Percy works out an answer**, the hold drops that answer (`PercyController.interruptTurn`,
  `_turnToken`): it is neither spoken nor acted on.
- **Reader:** stopping the speech leaves the current sentence unfinished; `ReaderController` saves that
  index, so "ituloy" replays the interrupted sentence (not verified on the tablet).
- **TalkBack on:** the gesture area is off (TalkBack owns touch), so `GestureSurface` offers the same
  action as a custom TalkBack action "Makinig ngayon" (`gestureHoldListenAction`). **Unverified:** whether
  TalkBack exposes it on the screen's root node.

**False "Hindi gumagana ang pakikinig ng boses ko ngayon" (likely cause, from reading the code, not
confirmed with a device log):** `HybridSpeechInput` passed Android recognizer errors through even while
the app's own offline recognizer was listening (only statuses were filtered). A late error of an
earlier, cancelled Android session was counted as the offline session failing; after 3 in a row
`VoiceController._giveUp` spoke the message while the offline session still delivered the command a
second later. Fixes: stale Android errors are ignored during an offline session; `_giveUp` now also
closes the session so a late result cannot run after the message. If it still happens, send the
`[VOICE ...]` lines around "giving up" (`adb logcat -s flutter`).

## Voice reliability (2026-10-17, branch `fix/voice-reliability`)
Problems on the tablet: commands had to be said twice, the hold had to be done twice, and
"Hindi gumagana ang pakikinig…" was said while commands still worked. Root causes, found by
reading the code and the `speech_to_text` 7.5.0 plugin (Android side) and reproduced in
`test/core/voice/voice_reliability_test.dart` (these tests fail on the old code):
1. **Android events have no session id.** The plugin sends `done` *before* the error that
   explains it (`onError` posts the error, sends the statuses at once), and a cancelled
   session's late events land on the next session. The controller took every Android error
   as "ended at once without result": a busy recognizer counted toward giving up, and language
   and network errors never reached their own handling.
2. **The hold cancelled its own session.** The hold ran as a command, and a command while
   listening restarts the session after 0.2 s; the hold then closed that new session and
   opened another at once, and the closed session's late `done` ended it → "Wala akong
   narinig" → hold again.
3. **The "listening" tone played before the mic was open.** The plugin reports `listening`
   before Android starts recording (`onReadyForSpeech` is empty in the plugin); words said
   right after the tone were lost → say it twice.
4. **Offline mic open/close overlapped.** A new offline session could start its mic while the
   old session's `micStop` was still on its way (native `micStart` returns true when already
   recording), so the stop killed the new session's mic; a cancel during mic start left an
   orphan session.
5. **A stop during voice selection was lost.** `HybridTtsService.speak` / `FlutterTtsService.speak`
   await voice lists / setup first; a stop meanwhile (the hold) was forgotten and the prompt
   started over the listening.
6. **Late results were thrown away** after giving up (the session was discarded).

Fixes:
- `SttSpeechInput` waits `recognizerSettle` after a stop/cancel and drops the old session's
  events meanwhile (`lib/core/voice/speech_input.dart`).
- `VoiceController` (`lib/core/voice/voice_controller.dart`): waits `errorAfterDone` after a
  `done` for the real error; events of a session the app just closed are **stale** → quiet
  restart (max 2 in a row); a session whose mic delivered sound never counts toward giving up;
  `error_busy`/`error_client`/no-result need `deadRecognizerAfter` (5) sessions without any
  sound; the give-up message waits `giveUpGrace` and a late result cancels it and runs; the
  session is no longer discarded on giving up.
- **Tone when the mic is live:** the "listening" earcon plays on the first sound level from the
  mic (Android RMS or the offline mic's first chunk), after `cueFallback` at the latest.
- **One hold = one session:** `listenNow` ignores a second call while it is opening a session;
  no automatic restart may start meanwhile; the hold command no longer triggers the
  command-while-listening restart.
- `OfflineCommandListener`: mic opens and closes one after the other (`_serial`); a cancel
  during mic start closes the mic again (`lib/core/offline_voice/offline_listener.dart`).
- TTS: a `stop()` counter makes a stop that lands during voice selection stick
  (`hybrid_tts_service.dart`, `tts_service.dart`).
- Whisper is warmed up (one decode of 0.5 s of silence) when it loads, so the first command
  isn't the slow one (`command_recognizer.dart`).
- **Noise (low-risk only):** the app's own mic asks for the phone's `NoiseSuppressor` (AGC off by
  default; `AudioBridge.kt`, `VoiceConfig.micNoiseSuppressor/micAutoGain`). The controller
  judges the room (level readings before the words, words that never stop changing, Android
  confidence < 0.5); in noise a command between 0.45 and 0.6 similar is asked back with
  "Medyo maingay po. Ito po ba ang ibig ninyong sabihin: …?" (`voiceNoisyDidYouMean`) instead of
  "not understood" (`CommandBus.handleUtterance(noisy:)`). Percy's thresholds are unchanged.
  The offline mic's sound level is now measured from a quiet room (−60 dBFS) on about Android's
  scale (`OfflineCommandListener.soundLevel`), not relative to a moving noise floor.
- **Repeatable tablet test:** developer build, Settings → Pagsusuri ng boses → "Pagsubok ng 20
  utos" (quiet / noisy) → `voice-trials.csv` (`lib/core/voice/voice_trial.dart`); checklist
  `docs/testing/voice-reliability-checklist.md`.

Log lines to look for: `stale … restarting quietly`, `microphone live after …ms`,
`no sound from the microphone … cue anyway`, `giving up … (message in 1500ms …)`,
`"voice not working" message dropped`, `noisy room …`, `recognizer settling …ms`.
**Not verified on the tablet** (no device run). The Android settle and the RMS-based tone depend
on the phone's recognizer and are only tested with fakes.

## Startup loading screen, busy phases, push-to-talk (2026-10-17, branch `fix/voice-startup-ptt`)
**Tablet test after `fix/voice-reliability`:** at app start (login, register, "Subukan muna")
holding kept saying the "not working / hihinto muna ako" message and commands had to be said 2â€“3
times; responses were slow; Home was fine; right after an upload a hold gave "voice is not
working" and was slow for a while. No `voice_log.txt` was in the repo, so the causes below come
from the code and the plugin sources, each reproduced by a test that fails on the old code
(`test/core/voice/voice_startup_ptt_test.dart`, `test/features/reader/reader_hold_test.dart`).

**Root causes**
1. **A failed recognizer set-up was final.** `VoiceController._createRecognizer` set
   `_initialized = true` even when Android's `initialize()` returned false (it can, while the
   app is starting and the phone is busy). From then on every hold went to `ensureReady` â†’
   "Walang speech recognitionâ€¦" (and voice mode was switched to gestures) â€” until the app's
   own Whisper model finished loading in the background and `commandsReady` turned true.
   That is the "after a while it works".
2. **Busy-time failures counted toward giving up.** At startup the offline voices and Whisper
   load (`OfflineEngines.load`, unawaited in `bootstrap()`), Percy's model loads, the first
   screens auto-listen (`autoListen: true` on every auth screen) and prompts start and cancel
   sessions. Sessions that failed meanwhile (busy, no sound) counted toward
   `voiceRepeatedError` like a broken recognizer.
3. **The hold opened the microphone while the app's voice was still finishing.**
   `Announcer.stop()` returned once `stop()` was sent, not when the sentence had ended. The
   app's own voice (`OfflineSpeaker.speak`) only noticed the stop after the audio piece it was
   generating was done (seconds for a long piece), and `HybridTtsService.speak` waited for the
   voices to load (seconds at startup) even after a stop.
4. **After an upload the Reader read over the hold.** `ReaderScreen._announceThenRead` awaited
   the "document ready" announcement and then started reading. A hold during the
   announcement stopped it â€” so the announcement returned early â€” and reading started at
   once, closing the hold's listening session (`_onSpeechChanged`: "reading started: closing
   the command session").
5. **ML Kit decodes the photo on Android's main thread.** `google_mlkit_commons`
   `InputImageConverter.handleFileImage` calls `InputImage.fromFilePath` in `onMethodCall`,
   i.e. on the Android UI thread, which also carries the speech recognizer callbacks, TTS
   callbacks and the app's mic bridge. The first OCR also creates the recognizer there.
   (From the plugin source; the size of the effect on the tablet is **unverified**.)

**Fixes**
- **Loading screen** (`lib/features/startup/startup_screen.dart`, route `AppRoutes.startup`
  `/start`, tasks in `lib/core/startup/startup_tasks.dart`): every cold start, after the
  first-launch model download when that is needed, says "Pakihintay po, inihahanda ang
  Percipere." and runs in parallel: settings/database (already open), the voice
  (`engines.voicesLoaded` + voice check), the recognizers (`engines.loaded` â€” Whisper loads
  with its silent warm-up decode â€” then Android's `warmUp()`), Percy's model, ML Kit (OCR and
  image labeling each run once on a 64Ã—64 blank PNG). Progress bar + one line per step, with a
  live-region Semantics label ("Inihahanda ang Percipere: 3 sa 5 ang handa na"). All done â†’
  "Handa na po." + the "heard" tone â†’ the first screen. After `StartupConfig.timeout` (15 s) â†’
  "May ilang bahagi pa pong naglo-load, pero puwede na po kayong magsimula." once, the first
  screen, and the rest loads in the background. It never stays on the screen if a step throws
  or a sentence never ends (10 s cap per sentence). Not a command screen (no actions, no
  gesture area). The `[STARTUP]` log line gives the time per step and since launch
  (`launchClock`, started in `main()`).
- **Voice readiness** (`lib/core/voice/voice_readiness.dart`): `VoiceBusy.startup` (loading
  screen open: no auto-listening, a hold says "Sandali lang po." once), `loading` (background
  loading after the timeout) and `processing` (the Reader extracting a document). While any is
  in force, or `OfflineEngines.loading`, and `VoiceConfig.busyGrace` (4 s) after, failed
  sessions restart quietly every `busyRetry` (0.8 s, at most 20 in a row) and never count
  toward "Hindi gumaganaâ€¦"; a pending give-up message is dropped.
- **Recognizer set-up is retried** (`_initRecognizer`): a failed set-up is tried again after
  `initRetryAfter` (1.5 s); only `initAttempts` (3) failures with nothing loading mean "no
  recognizer". A hold meanwhile waits up to `busyWaitMax` (10 s), saying "Sandali lang po."
  once; automatic listening just retries.
- **Wait for speech to stop:** `Announcer.stopAndWait()` stops, waits until the sentence has
  really returned (â‰¤ `speechStopWait` 1.5 s; not with TalkBack) and then
  `audioFocusRelease` (200 ms). Used by `listenNow` and `dictate`. `OfflineSpeaker.speak` and
  `HybridTtsService.speak` now return at once on `stop()`.
- **Reader:** extraction runs with `VoiceBusy.processing`; auto-read is skipped when the user
  held to speak or gave a command during the announcement (`VoiceController.userTurnSince`).
  OCR itself was already native/async and the Dart-side heavy work already in isolates
  (cleanup, insights, Otsu, quality check); the ML Kit warm-up moves the recognizer creation
  to the loading screen. The main-thread photo decode (cause 5) is **not changed** (it is in
  the plugin): see `06`.
- **Push-to-talk** (`gesture_classifier.dart`, `gesture_map.dart`, `command_bus.dart`,
  `voice_controller.dart`): a finger held still for `holdToListen` (now **450 ms**, just above
  the longest tap, 400 ms; under 0.3 s never listens) sends `longPress` â†’ `CommandBus.onGesture`
  calls `VoiceController.holdStarted()` then runs `NavIntent.listen` as before (screens that
  dictate on a hold â€” login, register, report text â€” get it too). Any session opened while the
  finger is down is a push-to-talk one: silences don't end it (`pushToTalkMax` 20 s), the
  4 s noise cap is off. Lifting the finger sends `GestureType.holdRelease` â†’
  `NavIntent.listenRelease` â†’ `releaseHold()`: after `pushToTalkReleaseGrace` (400 ms) the
  session is stopped (`stop()`, keeps the words) and what was said runs; a lift before the
  session opened gives an ordinary session; that end never counts as a failure. The release
  is never a command of its own (handled first in `dispatch`, so it never ends Percy). The
  hold is released if the touch is cancelled, the gesture area goes away, the screen changes
  or the app goes to the background. **TalkBack:** the gesture area keeps a hold-only touch
  listener (TalkBack's double-tap-and-hold passes a held touch through) and also offers
  "listen now" as its long-press and custom action (no release from those: a silence ends
  the session). **Unverified on the tablet** which of the two TalkBack delivers.
- **Developer voice-state overlay:** Settings (developer build) â†’ "Estado ng boses
  (developer)": a label at the bottom-left of every screen â€” loading / ready / speaking /
  listening / processing (`voiceActivityProvider`, `lib/core/voice/voice_activity.dart`) and
  the last cold start's load time. Every change is also logged as `[VOICE STATE] <state>`;
  busy changes as `[VOICE STATE] busy: â€¦`.
- Tutorial and help texts say "Pindutin nang matagal habang nagsasalita, bitawan kapag tapos
  na." (`tutorialLongPress`, `tutorialDone`, `gestureAreaHintMenu`, `helpWelcome`,
  `helpGesturesMenu`, `helpForm`, `helpReader`; English too).

Not changed: Percy's thresholds, the speech engines, what leaves the phone (nothing).
Log lines: `[STARTUP] ready|timed out after â€¦ms â€¦ steps: â€¦`, `while the app is busy: not
counted`, `recognizer not ready yet: waiting`, `initialize() returned false (n/3)`,
`push-to-talk released: finishing in 400ms`, `auto-read skipped: the user is talking`,
`speech still finishing after â€¦ms`.

## Command matcher (`lib/core/voice/command_matcher.dart`)
Normalize → phrase contained word for word (score 1 + 0.01/word, longer wins) or Levenshtein
similarity. **≥ 0.8 run, 0.6–0.8 ask "Ang ibig mo bang sabihin ay …?"**, below → not understood.
Order: current screen's action labels and `voiceSynonyms`, then app-wide phrases
(`lib/core/voice/voice_commands.dart`, `globalVoiceCommands`, yes/no words, wake word
"Percipere"). Extras in `CommandBus`: partial results, other recognizer guesses, command at the
end of a sentence, carry-over of cut-off words, barge-in while reading (`barge_in.dart`, echo
filter against the sentences just read).

## Percy (self-built assistant)
- Pipeline: speech → `percy_text.dart` preprocessing → `intent_classifier.dart` (TF-IDF word
  1–2-grams + char 3–5-grams, model from `assets/percy/model.json`) → `slots.dart` →
  `dialogue_manager.dart` → CommandBus action → reply from `assets/percy/responses.json` /
  `persona.json`. Controller: `percy_controller.dart`.
- **Dataset:** `data/percy/intents.csv` (529 rows, 527 distinct, **27 intents**).
  Guide for the team: `docs/percy-dataset-guide.md`.
- **Training:** `scripts/percy/train.py` (+ `validate_dataset.py`, `percy_text.py`), venv
  `scripts/percy/.venv`, commands in `scripts/percy/README.md`. Outputs `assets/percy/model.json`,
  `model_alt.json`, `data/percy/reports/report-<date>.md`, `scripts/percy/test_vectors.json`;
  then `flutter test test/core/percy/intent_classifier_test.dart`.
- **Thresholds** (`lib/config/percy_config.dart`): act ≥ **0.60**, ask 0.30–0.60, below 0.30 or
  `out_of_scope` → "not yet" + suggestions; title match 0.70; up to 3 choices; 3 turns of
  history; silence reminder 9 s, goodbye 9 s later. Exact short commands (≤ 3 words) use the
  matcher first.
- **Accuracy** (`data/percy/reports/report-2026-10-13.md`): Logistic Regression C=30 balanced,
  test accuracy **83.8%**, macro F1 0.667, 5-fold CV macro F1 0.663 ± 0.030 (Naive Bayes 81.2% /
  0.649). Test set is only 80 sentences; many intents have 7–8 examples, so numbers are noisy.
- Percy never speaks or logs passwords; the analysis panel hides password fields; the turn log
  (`percy_turns`) has no document content and stays on the phone unless exported.
- ElevenLabs Percy (`lib/core/assistant/`, `AssistantBridge.kt`, `assistant/`) only in builds with
  `PERCIPERE_DEV=true` and its switch on.

## Percy classifier — PROVISIONAL evaluation (2026-10-16)

**PROVISIONAL. Not the official thesis result.** The fixed team test set has no phrases yet for the
5 new intents (`describe_image`, `more_detail`, `read_image_text`, `tutorial`, `set_speed`), so those
are **not evaluated**. Rerun `train.py` after the team adds them (see `06-known-issues-and-todo.md`).
Full report: `data/percy/reports/report-2026-10-16.md` (made with `train.py --provisional`).
`assets/percy/model.json` was retrained with it; confidence thresholds unchanged (0.60 act, 0.30 ask).

**Data.** `data/percy/intents.csv`: 1023 rows, 1003 distinct after normalization. 76 rows matching
`test_team.csv` were removed from training first (58 Team + 18 Starter variants such as "home po").
570 reviewed `Generated (Codex)` rows were added. The team rows are therefore **not in training** (all
58 are the test set); every intent has 0 Team rows in training.

**Primary: 58 fixed team-written sentences, 10 intents** (back, cancel, help, next_option, open_home,
open_library, open_settings, previous_option, select, where_am_i). Not evaluated: the other 22 intents,
including the 5 new ones.

| Model | Accuracy | Macro F1 | 5-fold CV macro F1 (training data) |
|---|---|---|---|
| Before (old `model.json`) | 1.000* | 1.000* | n/a |
| Naive Bayes (alpha 0.03) | 0.897 | 0.932 | 0.860 ± 0.023 |
| **Logistic Regression, class_weight=balanced (C 30) — chosen, exported** | **0.966** | **0.971** | **0.893 ± 0.028** |
| Logistic Regression, no weighting (C 100) | 0.966 | 0.978 | 0.889 ± 0.030 |

\* The old model had these same 58 phrases in its training data, so 1.000 is **not** a fair "before".
There is no honest before/after number yet. Chosen by CV on training data, not by the test set; the
balanced and unweighted LR differ by one sentence on the test set (noise). Naive Bayes is exported as
`model_alt.json`.

**Per intent (chosen):** all 1.00 precision/recall/F1 except `help` 0.86/0.86/0.86 and `select`
1.00 recall 0.75 (F1 0.86). Confusion: `help`→`tutorial` 1 ("pano toh gamitin", confidence 0.94),
`select`→`help` 1 ("proceed", confidence 0.10). The first is the `paano gamitin` help-vs-tutorial
question in `06`. Confidence bands: ≥ 0.60 act 50 sentences 98% correct; 0.30–0.60 ask 6, 100%;
< 0.30 fallback 2, 50%. No measured reason to change the thresholds.

**Secondary (all training data, 70/15/15 split, 151 test sentences):** Naive Bayes accuracy 0.887,
macro F1 0.873; Logistic Regression 0.907 / 0.903. These sentences are mostly generated/starter text, so
they say little about real users.

**Data share (team / generated / starter):** 32 of 32 intents are below 2/3 team-written (flagged
LOW). Only 10 intents have any team text (2–8 phrases, all used as the test set); 22 intents have 0.
The 5 new intents are 100% generated. Per-intent table: the report.

**Caveats:** very small test set (2–8 per intent); the generated text may be unnatural; Starter and
Generated rows are not independent of each other's wording.

## Online-only parts
Dictation and Percy listening (without Google's offline pack); account register/reset/verify;
admin books (browse/download); reports sending/status; detailed image description (mocked);
the first model download.

## Known voice problems (details and priorities in `06-known-issues-and-todo.md`)
- Offline recognizer accuracy measured only on synthetic speech and FLEURS recordings
  (45% word error rate on real Filipino sentences); real tablet accuracy unknown.
- No partial results from the offline recognizer → reading is not paused ("ducked") while the
  user speaks over it.
- First prompt after app start can be late while the offline voices load (since 2026-10-17 this
  happens on the loading screen, before the first screen).
- Android path history (2026-10-14): slow responses and missed commands in noise were the
  reported problems; fixes are built but not tablet-tested.
- 2026-10-17 reliability fix (above) not tablet-tested; the offline voice detector still splits a
  command at a pause longer than `offlineEndOfSpeech` (0.7 s), e.g. "buksan … ang aklatan".
- TalkBack itself may read typed password characters (outside the app's control).
