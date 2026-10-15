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
Silences on the Android path are timed by the app, never handed to Android (decision 2026-10-14).
Earcons (`ToneGenerator`, channel `ph.bataan.percipere/sound`): "heard", "listening", "stopped".

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

## Online-only parts
Dictation and Percy listening (without Google's offline pack); account register/reset/verify;
admin books (browse/download); reports sending/status; detailed image description (mocked);
the first model download.

## Known voice problems (details and priorities in `06-known-issues-and-todo.md`)
- Offline recognizer accuracy measured only on synthetic speech and FLEURS recordings
  (45% word error rate on real Filipino sentences); real tablet accuracy unknown.
- No partial results from the offline recognizer → reading is not paused ("ducked") while the
  user speaks over it.
- First prompt after app start can be late while the offline voices load.
- Android path history (2026-10-14): slow responses and missed commands in noise were the
  reported problems; fixes are built but not tablet-tested.
- TalkBack itself may read typed password characters (outside the app's control).
