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
| `micNoiseSuppressor` / `micAutoGain` | on / **on** (2026-10-18; was off) | phone noise suppressor / AGC on the app's own mic (offline commands) |
| `halfDuplex` | on | never listen while the app speaks; no barge-in (2026-10-17, `fix/voice-capture`) |
| `micAudioSource` / `micEchoCanceller` | **`voiceCommunication`** (2026-10-18; was `voiceRecognition`) / on | Android audio source and echo canceller of the app's own mic |
| `noiseSettle` / `noiseSustain` / `noiseOnsetLag` / `noiseWindow` | 0.7 / **2** (was 1) / 0.7 / 8 s | noise floor: ignore after app speech; stay high this long; drop before the user's words; forget |
| `speechGuard` / `toneGuard` / `toneMax` | 0.25 / 0.25 / 0.6 s | half-duplex: no audio this long after the app's speech / after a tone; longest tone mute |
| `audioFocusRelease` | 0.25 s (was 0.2) | push-to-talk / dictation: gap after the speech stopped |
| `preRoll` / `micLinger` | 0.3 / 1.5 s | the app's mic stays open this long after a silent session; what it hears goes to the next session |
| `calibrationTime` / `speechMargin` / `noiseStale` | 1 s / 2 / 60 s | room measurement; speech threshold = room + margin; measure again after this (or when noisy) |
| `listenWatchdogSlack` | 3 s | a session still open this long after its own limit is closed by force |
| `ttsFailuresBeforeSwitch` | 2 | a quickly failing Android voice is tried once more before the app's own voice takes over |
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

## Percy's bundled ElevenLabs voice (2026-10-17, branch `feat/percy-elevenlabs`)
Percy's **fixed** sentences are spoken with the team's ElevenLabs voice (`u0P5zPuh3SvxTi9vSTCn`,
not a secret) from clips bundled in the app: offline, **no API key in the app, no server**.
- **Generation (run by the user, not by the app):** `tool/percy_voice/generate_percy_voice.py`
  (commands in `tool/percy_voice/README.md`). Reads `assets/percy/responses.json` (intents,
  dialogue), the `persona.json` greeting and the ARB keys in `tool/percy_voice/extra_arb_keys.json`
  (tutorial lines, mic/unavailable messages), cuts them into **sentences** (the Announcer speaks one
  sentence at a time), skips sentences with `{placeholders}`, and writes one mono mp3
  (`mp3_22050_32`, model `eleven_multilingual_v2`) per sentence to `assets/percy/voice/`
  plus `manifest.json` (hash -> file, lang, text, voice id, model, date). Key only from the
  environment variable `ELEVENLABS_API_KEY`. Re-runs skip finished clips. Dry run: 325 sentences
  (167 fil, 158 en), 8,507 characters.
- **Key:** first 16 hex of `sha256("<lang>|<text>")`, whitespace collapsed (`PercyClipKey`,
  `lib/core/percy/percy_clips.dart`); a test checks it equals the script's hash.
- **Since 2026-10-17 (`fix/voice-capture`):** clips play only for Percy's own lines, and only when
  every sentence of the line has one; app prompts (incl. the ARB extras such as tutorial lines)
  always use the app voice. See "Voice capture and one output voice".
- **Playback:** `Announcer._drain` asks `PercyClips.play` first; `notFound` or `failed` -> the
  existing offline voice speaks the sentence (never silent); `stopped` -> nothing more. Document
  reading (`ReaderController`) does not use this path. Native `playClip` in `AudioBridge.kt`
  decodes the mp3 (MediaExtractor/MediaCodec) and plays it on the same `AudioTrack`, audio focus
  and volume as the offline voice; speech speed = `PlaybackParams` speed (pitch kept, clamp 0.5-2).
- **Push-to-talk:** `Announcer.stopAndWait` -> `_stopSpeech` stops the TTS **and** the clip
  (`playStop`); a stop while the clip is still loading keeps it from starting.
- **Settings > Percy** row "Boses ni Percy": "ElevenLabs (offline), N sa M na linya ang may clip"
  (M = fixed sentences of `responses.json` + persona; ARB extras are not counted), or "Offline na
  boses ng app (wala pang clip)" with zero clips. `assets/percy/voice/manifest.json` is committed
  empty: **the app works with zero clips**.
- Not changed: Percy's model, thresholds, the reader's voice. Lines with `{title}` etc. use the
  offline voice. **Unverified on a device:** mp3 decoding and `PlaybackParams` on the tablet
  (only the Dart side is tested, with fakes); release build not run.

## Voice capture and one output voice (2026-10-17, branch `fix/voice-capture`)
**Tablet test after push-to-talk + loading screen:** recognition still poor; the mic sometimes
heard the app's own voice (Percy / the Reader through the speaker) → "Medyo maingay po…" and wrong
results; the output voice changed a lot, the tone sometimes got "stuck". No `voice_log.txt` was in
the repo, so the causes below come from reading the code; each code cause has a test that
reproduces it (`test/core/voice/voice_capture_test.dart`, `engine_selection_test.dart`,
`percy_clips_test.dart`). **None is confirmed with a tablet log.**

**Root causes (capture)**
1. **"Too much noise" from the app's own voice and the user's first word.** The room was judged by
   the first 5 level readings of each session (`noisyMinReadings`) before the first partial
   result. Auto-listening opens 0.45 s after the app stops talking, so those readings held the
   speaker's echo/reverb; with push-to-talk the user talks at once, so they held the user's own
   first syllables (the recognizer reports words 0.3–0.6 s late). Either way: "noisy" → ask-back.
   A low recognizer confidence (or 0.0, which Android's on-device recognizer gives when it has no
   score) also said "Medyo maingay po", although the room was quiet.
2. **The app listened while it read aloud.** "Makinig habang nagbabasa" (barge-in, on by default)
   kept a session open during document reading; the echo filter only drops words that match the
   read text, so misheard echo could still run a reading command (e.g. "bilisan" → faster,
   which then *stays* faster: one possible "stuck" speed).
3. **Push-to-talk ended at the first pause.** With the app's own recognizer, the voice detector's
   end of speech (0.7 s) finished the session and the 4 s speech cap flushed it while the finger
   was still down; with Android's recognizer, Android ends the session after a pause by itself,
   and a strong partial ("basahin") ran before the rest ("… ang Liham").

**Root causes (output voice)**
4. **One reply, two voices.** The Announcer played a Percy ElevenLabs clip for *any* sentence
   with a clip (also app prompts: the tutorial/mic lines in `extra_arb_keys.json`) and the app's
   voice for the next sentence without one. (On the tablet `assets/percy/voice/` is still empty,
   so this was not the cause there yet, but would have been once clips are added.)
5. **Engine flip-flop.** When an Android voice failed, `HybridTtsService` spoke that one sentence
   with the app's offline voice (MMS Tagalog / Piper: a different voice, no pitch) and went back
   to the failing Android voice for the next one. A slow sentence that hit the 5 s + 150 ms/char
   time limit counted as a failure while Google TTS was still talking → both voices at once.
6. **Speed/pitch only sent on change.** `FlutterTtsService` set the speech rate only when it
   changed and the pitch only at startup / in Settings; if the engine lost them (language/voice
   switch, engine restart) the voice stayed at another tone/speed until the setting was changed.
7. **Audio-focus leak in `AudioBridge.playPcm`.** A stop that landed between the generation check
   and `requestFocus()` left a `GAIN_TRANSIENT_MAY_DUCK` focus held (never abandoned), which can
   keep other sound (Google TTS runs in its own process) ducked → quieter/odd tone. **Unverified**
   that this happened on the tablet.

**Fixes**
- **Half-duplex** (`VoiceConfig.halfDuplex = true`): no barge-in sessions while reading (the
  Settings row "Makinig habang nagbabasa" is hidden while this is on); `_start` refuses to open
  automatic sessions while a prompt, Percy, a clip or the document is playing (log `start skipped:
  the app is speaking`); auto-listening starts only when the speech has ended + `afterSpeechGap`
  (0.45 s). Push-to-talk and dictation already stop all speech and wait for it to end
  (`Announcer.stopAndWait`: drain done + `audioFocusRelease` 200 ms) before the mic opens.
- **Noise floor** (`lib/core/voice/noise_monitor.dart`, `NoiseMonitor`): level readings count as
  room noise only while the app is silent, from `noiseSettle` (0.7 s) after its speech (`noiseToneSettle`
  0.3 s after a tone);
  never from the user (readings `noiseOnsetLag` 0.7 s before the first partial / the voice
  detector's speech start are dropped, later ones ignored); measured afresh every time the app
  stops speaking; forgotten after `noiseWindow` (8 s). Noisy = at least `noisyMinReadings`
  readings spanning `noiseSustain` (1 s), `noisyShare` of them ≥ `noisyLevel` (thresholds
  unchanged). Only then "Medyo maingay po. Ito po ba …?"; an uncertain result (confidence
  0 < c < 0.5, or words that never stopped changing) is asked back with the plain "Ito ba ang ibig
  mong sabihin …?" (`CommandBus.handleUtterance(noisy:, uncertain:)`). Both lower the ask-back
  floor to `noisyAskScore` (confirm instead of refusing). Percy's thresholds unchanged.
- **Push-to-talk capture:** `ListenRequest.pushToTalk`. App recognizer: no speech cap, segments
  are not reported one by one; on the release Whisper decodes **all** the held audio at once, from
  0.5 s before the first speech (pre-roll; `CommandRecognizer.begin(whole: true)`). Android
  recognizer: no partial runs while held; if Android ends the session itself, the words are kept
  and a new session opens at once (`_keepHolding`, log `push-to-talk: … while held: listening
  on`); the release (after the 400 ms grace) acts on everything; a release between two sessions
  acts at once. Ordinary sessions keep the 0.4 s pre-roll per segment.
- **Mic source and effects** (`AudioBridge.kt` `micStart`): source from
  `VoiceConfig.micAudioSource` (`voiceRecognition`, the Android source meant for speech
  recognition; `voiceCommunication` is the other choice and the fallback when the first can't be
  opened); `AcousticEchoCanceler` and `NoiseSuppressor` on when the phone has them
  (`micEchoCanceller`, `micNoiseSuppressor`); **AGC stays off** (`micAutoGain`): it pumps the
  background up between words (breaks the voice detector's end of speech and would make the noise
  floor read high), and Whisper normalizes the level itself. The answer says what is really on;
  log `[OFFLINE VOICE] microphone: voiceRecognition AEC NS`. **Android's recognizer**
  (`speech_to_text`) picks its own source and effects: the app can't set them.
- **One output voice:** app prompts never play Percy's clips; a Percy line
  (`CommandBus.say(percyVoice: true)`, from `PercyController._say`) plays clips only when *every*
  sentence has one, else the whole line uses the app voice. `HybridTtsService` keeps one route per
  language for the run (`_routes`); it changes only when that voice fails (then for good) or from
  the network last resort once an offline voice is ready; every change is logged `[TTS] engine
  switch for fil-PH: androidLocal → bundled (Android voice failed)`. A new reading-voice choice in
  Settings picks afresh. `FlutterTtsService` sets rate and pitch before **every** utterance (log
  `[TTS] android voice: <name> (<tag>) rate … pitch …` when they change) and stops the engine when
  it doesn't answer in time, so no second voice talks over it. `AudioBridge` requests audio focus
  under the same lock as the stop check and always gives it back.
- **Overlay** ("Estado ng boses (developer)"): adds "Pinakikinggan sa: app mic: voiceRecognition
  AEC NS" / "Android recognizer" and "Lakas ng tunog: <last level> · kuwarto: <floor>" (+ MAINGAY)
  (`VoiceCaptureStatus`, `voiceCaptureProvider`).

Not changed: speech engines, Percy's thresholds, `noisyLevel`/`noisyShare`/`lowConfidence`,
document language → voice language (an English document is still read by the English voice;
"one voice" means one voice **per language**, kept for the whole run).
Log lines: `start skipped: the app is speaking`, `noisy room (level …)`, `uncertain result`,
`push-to-talk: … while held: listening on`, `push-to-talk released between sessions`,
`[OFFLINE VOICE] microphone: …`, `[TTS] engine switch …`, `[TTS] android voice: …`,
`[TTS] no answer from the engine: stopping it`.

## Half-duplex turns, room calibration, pre-roll, tone (2026-10-18, branch `feature/no-email-profiling-describe`)
**Tablet test (Samsung Galaxy Tab S10 Lite):** the mic heard the app's own voice ("too much noise",
false commands); the listening tone sometimes got stuck; commands had to be said 2–3 times (better
on Home than elsewhere); the output voice changed between screens. These are the same symptoms
`fix/voice-capture` (above) targeted; **unverified** whether the tested APK was built after `11b65f8`.
No device log was available, so the causes below come from the code; the fixes are tested in
`test/core/voice/voice_turns_test.dart` (29 tests) and `test/core/offline_voice/engine_selection_test.dart`.

**Causes found in the code (not confirmed with a tablet log)**
1. **The app's own mic closed and reopened every few seconds.** An automatic command session with no
   speech ends after `waitForSpeech` (4 s); `OfflineCommandListener` then stopped the `AudioRecord`
   and the next session opened a new one (permission check, recorder and effects set-up): words
   said in that gap, or their first syllable, were lost.
2. **On screens with a question, instructions were spoken over the user.** `Announcer.ask` holds
   back its instructions for `answerWait` (6 s) and restarts the wait on the user's words
   (`userResponding`), but only Android's partial results called it; the app's own recognizer
   has no partials, so the instructions started while the user was talking and cancelled the
   session (half-duplex). Home asks no question: "works better on Home".
3. **"Medyo maingay po" from one loud second.** The room counted as noisy after 1 s of loud
   readings, with one fixed level (4) whatever the room normally sounds like.
4. **The tone could keep sounding.** `ToneGenerator.startTone(tone, ms)` relies on the device to
   stop the tone; nothing stopped it on a screen change or app pause.
5. **A session could stay "listening".** If the recognizer never ended a session (no `done`, no
   result), nothing closed it.
6. **One hiccup changed the voice for good.** One failed Android TTS call (an error) moved that
   language to the app's own voice (MMS Tagalog / Piper) for the rest of the run.
7. **The listening tone reached the app's own mic** (the cue plays once the mic is live).

**Fixes**
- **Turn state machine** `lib/core/voice/mic_turn.dart` (`MicTurn`, `MicPhase` idle / speaking /
  wait / listening / done / timeout), driven by `VoiceController`: speaking → `speechGuard`
  (250 ms) wait → listening. Automatic sessions don't start during the wait; push-to-talk and
  dictation wait for it (`MicTurn.ready`) after `Announcer.stopAndWait` (250 ms focus gap). Every
  session gets a **watchdog** (`listenFor` + 3 s → closed, phase `timeout`). A **screen change**
  closes the open session (not a dictation or a held push-to-talk) and the pending tone; **app
  paused** closes listening, the tone (`Earcon.stop`) and the app's mic. Log: `mic turn: …`,
  `watchdog: the session never ended`, `screen changed: closing the open session`.
- **The mic closes before the app talks:** each time speech starts, `SpeechInput.releaseMic()`.
- **Pre-roll** (`OfflineCommandListener`): after a session that heard nothing the mic stays open
  `micLinger` (1.5 s); the next session gets all audio heard meanwhile (always more than
  `preRoll`, 300 ms), on top of the recognizer's own 0.4 s per-segment pre-roll. A heard command,
  a cancel or `releaseMic` close the mic. Log: `[OFFLINE VOICE] microphone kept open: …ms before
  the session`. Android's recognizer owns its mic: no pre-roll is possible there.
- **Tone mute:** the "listening" cue still plays when the mic is live (so words right after it
  aren't lost), but the app's mic drops its audio while the tone plays and `toneGuard` (250 ms)
  after it (`SpeechInput.muteAudio`). Android's recognizer can't be muted (it hears the ~50 ms tone).
- **Tone player:** `android/.../TonePlayer.kt` replaces `ToneGenerator`: fixed-length tones from a
  static buffer, released after their own length at the latest; the call answers when the tone
  has ended; `stop` and `MainActivity.onPause` silence it.
- **Room calibration** (`NoiseMonitor.calibrate`, `VoiceController.calibrateNoise` / `_measureRoom`,
  `SpeechInput.measureRoom`): 1 s measured with the app's mic on the loading screen (after the
  recognizer step, once the screen is quiet), and again before the first automatic session on a
  screen opened while the room was noisy or the last measurement is older than 60 s. A second of
  quiet before the user speaks also updates it. **Speech threshold** = room + `speechMargin` (2,
  about 6 dB), at least 3: the app's recognizer ignores speech no louder than that
  (`ListenRequest.speechThreshold`; not for push-to-talk or dictation). Log: `room measured
  (warm-up): level …, speech threshold …`, `[OFFLINE VOICE] ignored: level … below the speech
  threshold …`. "Medyo maingay po" needs the room loud for `noiseSustain` (now 2 s).
- **Mic source and effects:** `voiceCommunication` + echo canceller + noise suppressor + **AGC on**,
  as asked (each only when the tablet has it; the overlay and the `[OFFLINE VOICE] microphone:` line
  say which are on). **`speech_to_text` (Android's recognizer: dictation, Percy, and commands while
  the model isn't downloaded) can't be given an audio source or effects by the app**: the plugin
  has no option for it. That would need our own recognizer bridge feeding
  `RecognizerIntent.EXTRA_AUDIO_SOURCE` (Android 13+) from our own recorder: a bigger change, not
  done (ask first).
- **The user's speech holds back instructions:** the voice detector's speech start now calls
  `Announcer.userResponding()`.
- **One output voice:** the settings source is unchanged (`settingsProvider`: rate, pitch, reading
  voice → `TtsService`; per language one route kept for the run, `HybridTtsService._routes`;
  prompts and the Reader both use `readingRateProvider`). New: an Android voice that fails
  **quickly** is asked once more with the same voice; only a second failure (or one that never
  answered) moves that language to the app's own voice for good. The overlay shows the voice of
  every prompt.
- **Debug overlay** ("Estado ng boses (developer)" in Settings; now also in every **debug** build):
  mic turn state, source, sound level / room / speech threshold, last transcript + confidence,
  what it matched, the app's output voice (`VoiceCaptureStatus` in `noise_monitor.dart`; ARB
  `voiceStateMic`, `voiceStateThreshold`, `voiceStateHeard`, `voiceStateMatch`, `voiceStateOutput`).

Not changed: push-to-talk (still stops the speech, waits, listens while held), the Whisper warm-up
decode, Percy's thresholds, `waitForSpeech`, `afterSpeechGap` (450 ms, already above the guard).
**Unverified on the tablet:** whether `voiceCommunication` + AGC helps or hurts Whisper; whether the
speech margin (2) rejects quiet speakers (lower it if real commands show `ignored: level …`); the
loudness of the new tones (0.32 of full scale).

## Percy answers questions (2026-10-18, branch `feat/percy-knowledge`)
Percy used to understand commands only ("Anong kaya mo?" fell to "not yet"). Now it answers questions
about itself and the app, offline, with no AI service.
- **Knowledge base:** `assets/percy/knowledge.json`: 32 topics (Percy: abilities, purpose, who, human,
  creator; the app; reading, scan, upload, PDF; talking, push to talk, gestures, what to say; Aklatan: use,
  download, favorite, collections; Maglarawan; text size, voice speed, colors; offline, privacy of
  documents and passwords, register, forgotten password, guest; help, stuck). Each has about 30 example
  questions (Filipino, English, Taglish, speech-recognition spellings) and a Filipino (po / casual) and
  English answer: 1-3 sentences + one follow-up ("Gusto ninyo po bang subukan? Sabihin lang ang “…”.").
  Edit the JSON to change an answer; no retraining for answers.
- **Retrieval:** `lib/core/percy/knowledge_base.dart`, TF-IDF + cosine similarity over the example
  questions, topic score = best question (algorithm 5 in `docs/thesis/algorithms.md`). Thresholds in
  `lib/config/percy_config.dart`: >= 0.55 answer, 0.35-0.55 "Ito ba ang tinatanong mo: …?" (yes answers,
  no suggests three example questions), < 0.35 "Hindi ko po sigurado…" + three example questions.
- **Routing:** new intent `ask_question` (`data/percy/intents.csv`, 993 rows, source "Generated (Claude)").
  `DialogueManager._askedQuestion` runs after the report-issue rule: the classifier says ask_question
  (>= 0.30), or a sentence with a question word is >= 0.85 similar to a known question. Commands stay
  commands; the old keyword `IntroRule` and the `introduction` line are no longer used (the `sino ka` /
  `ano ang kaya mo` rows moved from `greeting` to `ask_question`). `tulungan mo ako` and `hindi ko alam
  ang gagawin` moved from `help` to `ask_question`; the other `help` phrases (help me, patulong, i need
  help, naguguluhan ako, ...) stay commands and are not in the knowledge base; a bare "help" is still the
  exact command (the controller's matcher goes first).
- **Retrained provisionally** (`train.py --provisional`, `test_team.csv` excluded, report
  `data/percy/reports/report-2026-10-18.md`). Fixed team test set (58 sentences, 10 intents):
  accuracy **0.966 -> 0.914**, macro F1 **0.971 -> 0.939** (LR, balanced). The new mistakes: "anong gagawin ko"
  (help -> ask_question 0.46: Percy now answers with the stuck topic), "proceed" 0.23 and "pillin" 0.20
  (select -> ask_question, below the 0.30 line so they fall back instead of acting); the two "paano
  gamitin" help -> tutorial mistakes were there before. >= 0.60 band: 47 sentences, 100 %.
  `ask_question` itself is **not evaluated** on the team set (no team questions yet); the all-data
  70/15/15 split gives accuracy 0.936 / macro F1 0.896 (not comparable with before: new class).
  Retrieval alone (not in the list): leave-one-out 87.8 % of 345.
- **Voice clips:** `generate_percy_voice.py` now also reads the knowledge answers (dry run: 590 lines, 333
  fil + 257 en, 23,762 characters, 0 have clips), has `--check` ("N of M lines have clips", no key) and
  Settings > Percy shows "N sa M na linya ang may clip" counting the knowledge answers too. Hand-off for
  a teammate: `docs/percy-voice-handoff.md`. **Waiting for the clips**; the app works without them.
- Tests: `test/core/percy/knowledge_test.dart` (every example question -> right topic alone and through
  the real classifier + dialogue manager, in both languages; task-named questions; unseen wordings;
  leave-one-out; ask back; suggestions; no command row answered as a question).
- **Unverified:** real speech-recognition output on the tablet; how the answers sound (long: 3-4
  sentences); that casual Filipino answers read naturally (derived from the "po" text by rules).

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
- **Dataset:** `data/percy/intents.csv` (2,000 rows since 2026-10-18, **33 intents** incl. `ask_question`; 529 rows / 27 intents when this section was written).
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
