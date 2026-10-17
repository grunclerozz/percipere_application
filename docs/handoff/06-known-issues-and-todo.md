# 06 — Known issues and TODO

Collected from `docs/specs/decisions.md`, `docs/todo.md`, `docs/database/open-questions.md`,
`docs/features-summary.md` §5, `docs/testing/*`, `05-current-status.md` and the code. The code has no
`TODO`/`FIXME` comments. Priority: **High** = blocks the thesis demo/tablet use;
**Medium** = needed soon; **Low** = cleanup or later.

## High
| Issue / TODO | File(s) |
|---|---|
| Offline voice archives not uploaded (dashboard `models/` + GitHub release `voice-models-v1`); first launch download fails until then | `tool/voice_models/README.md`, `lib/core/offline_voice/model_catalog.dart` |
| Nearly all work since 7 Oct is untested on the tablet (voice, accounts, reports, Aklatan, revisions, offline voice) | `docs/testing/*.md`, `docs/handoff/05-current-status.md` |
| Offline command accuracy with real users unknown (Whisper tiny-tl: 45% WER on FLEURS sentences; synthetic commands 10/18 + 3 asked) | `lib/core/offline_voice/command_recognizer.dart`, `tool/voice_models/README.md` |
| App needs dashboard branch `fix/webapp-api` merged (state unverified) | dashboard repo; `docs/api-contract.md` |
| Unpushed commits on `main` (4) and `docs/database-masterlist` (4, as of 2026-10-16) | git; `05-current-status.md` → Branches |

## Medium
| Issue / TODO | File(s) |
|---|---|
| Percy offline – later: dictation and Percy still need Android's recognizer (internet or Google pack) | `docs/todo.md`, `lib/core/voice/voice_controller.dart` (`_planNow`) |
| Team test rows are no longer in training (leakage removal: 76 rows incl. all 58 Team rows), so every intent has **0 Team rows in training**; team-written share is low everywhere. `open_home`, `back`, `next_option`, `cancel`, `help` are under 30 phrases. Team should add more phrases (see `docs/percy-dataset-guide.md`) | `data/percy/intents.csv` |
| Test phrase `paano gamitin` is labelled `help` in `test_team.csv`, but the exact voice command `paano gamitin` / `how to use` now runs `tutorial` (`globalVoiceCommands`). Team decides which one it means; the tutorial test phrases must not collide with `help` ones | `data/percy/test_team.csv`, `lib/core/voice/voice_commands.dart` |
| 138 heuristic near-pairs in the generated batch were never reviewed by a human; unnatural phrases (e.g. `can you mag report ng problema`, `... para sa akin`) are in training | `data/percy/intents.csv` (source `Generated (Codex)`) |
| Team to add ~10 test phrases each for `describe_image`, `more_detail`, `read_image_text`, `tutorial`, `set_speed` to `data/percy/test_team.csv`, then rerun the official evaluation (no code changes needed, just rerun `scripts/percy/train.py` without `--provisional`; then replace the PROVISIONAL section in `03-voice-and-percy.md` and write `docs/thesis/percy-evaluation.md`) | `data/percy/test_team.csv`, `scripts/percy/train.py` |
| Voice latency not measured yet (needs tablet logs: `[VOICE TIMING]`/`[VOICE ...]` lines); Percy waits `percyPause` 2.2 s + `finalTimeout` 0.8 s on the Android recognizer. Plan: measure, then quick wins (Phase C) | `lib/config/voice_config.dart`, `lib/core/voice/voice_controller.dart` |
| **Fixed 2026-10-17, not tablet-tested:** "say it twice", "hold twice", false "Hindi gumagana ang pakikinig…" (root causes in `03-voice-and-percy.md` → Voice reliability). Run `docs/testing/voice-reliability-checklist.md` (20-command CSV test, quiet + noisy) | `lib/core/voice/voice_controller.dart`, `speech_input.dart`, `lib/core/offline_voice/offline_listener.dart` |
| **Fixed 2026-10-17 (`fix/voice-capture`), not tablet-tested:** mic hearing the app's own voice, false "Medyo maingay po", push-to-talk cut at the first pause, output voice changing / "stuck" tone (root causes in `03-voice-and-percy.md` → Voice capture). Half-duplex is on, so **listening while reading (barge-in) is off** and its Settings row hidden. Causes found by reading code only: confirm with a tablet log (`[VOICE …]`, `[TTS] …`, `[OFFLINE VOICE] microphone: …`) | `lib/core/voice/noise_monitor.dart`, `voice_controller.dart`, `AudioBridge.kt`, `hybrid_tts_service.dart`, `tts_service.dart`, `announcer.dart` |
| Whether the tablet has an echo canceller / noise suppressor for the app's own mic is unknown: read the overlay ("Pinakikinggan sa: …") or the `[OFFLINE VOICE] microphone:` line. If echo remains, try `VoiceConfig.micAudioSource = 'voiceCommunication'` and compare (its filtering may lower Whisper accuracy). Android's own recognizer chooses its source itself | `lib/config/voice_config.dart`, `AudioBridge.kt` |
| AGC kept off although asked for (pumps background noise between words, breaks end-of-speech detection and the noise floor; Whisper normalizes levels). Switch `micAutoGain` on only if the tablet log shows very quiet speech being missed | `lib/config/voice_config.dart` |
| Percy's ElevenLabs clips for the ARB extras (tutorial, mic messages in `tool/percy_voice/extra_arb_keys.json`) are no longer played (app prompts use the app voice). The generator still makes them; drop them from that list if not wanted | `tool/percy_voice/extra_arb_keys.json`, `lib/core/accessibility/announcer.dart` |
| Release build + `Percipere_Light` emulator check of the changed `AudioBridge.kt` (mic source/effects map, focus) not done in the `fix/voice-capture` task | `AudioBridge.kt` |
| Noisy rooms: low-risk part done 2026-10-17 (phone `NoiseSuppressor` on the app's own mic, AGC off; unsure commands asked back in noise). Noise thresholds (`noisyLevel` 4, `noisyShare` 0.5, `lowConfidence` 0.5) are guesses: tune from the CSV. No noise model (future work) | `lib/config/voice_config.dart`, `AudioBridge.kt` |
| Offline voice detector ends a command at a 0.7 s pause (`offlineEndOfSpeech`): a hesitating "buksan … ang aklatan" becomes two attempts. Raise the value if the CSV shows it | `lib/config/voice_config.dart`, `command_recognizer.dart` |
| The "listening" tone now waits for sound from the mic; if a phone's recognizer sends no sound levels, the tone comes after 1.5 s (`cueFallback`). Check the timing on the tablet | `lib/core/voice/voice_controller.dart` |
| Unverified on the tablet: hold stops Percy/Reader speech and listens; TalkBack custom action "Makinig ngayon" | `lib/core/gestures/gesture_surface.dart` |
| **Fixed 2026-10-17 (`fix/voice-startup-ptt`), not tablet-tested:** voice errors / "say it 2–3 times" at app start and right after an upload (failed recognizer set-up was final; busy-time failures counted; the hold listened before the app's voice had stopped; the Reader read over a hold). New loading screen, push-to-talk, developer voice-state overlay. Run `docs/testing/voice-startup-ptt-checklist.md`; report the cold-start load time | `lib/features/startup/`, `lib/core/voice/voice_readiness.dart`, `voice_controller.dart` |
| Cold-start load time not measured yet: no `Percipere_Light` AVD on the dev PC any more (2026-10-17) and no device run allowed. The app logs it (`[STARTUP] … since launch`) and shows it in the developer voice-state overlay | `lib/features/startup/startup_screen.dart` |
| ML Kit decodes each photo on Android's main thread (`google_mlkit_commons` `InputImage.fromFilePath` in `onMethodCall`), next to the speech recognizer, TTS and mic callbacks. Not changed (plugin code). If the tablet log still shows voice trouble during OCR: downscale large photos in an isolate before OCR (accuracy check needed) | `lib/core/ocr/ocr_service.dart` |
| Push-to-talk with TalkBack: which path TalkBack's double-tap-and-hold takes on the tablet (held touch passed through → release finishes the session; or a long-press action → a silence ends it) is unverified | `lib/core/gestures/gesture_surface.dart` |
| Hold time is now 450 ms (was 650 ms) for push-to-talk: a hand resting on the gesture area listens sooner. Raise `VoiceConfig.holdToListen` if that happens on the tablet | `lib/config/voice_config.dart` |
| Percy dataset small (many intents 7–8 sentences); add team sentences and retrain | `data/percy/intents.csv`, `docs/percy-dataset-guide.md` |
| Offline recognizer gives no partial results → no reading pause while the user speaks over it | `lib/core/offline_voice/offline_listener.dart` |
| First prompt after app start can wait for the offline voices to load (emulator: 5–20 s). Since 2026-10-17 this wait is on the loading screen (15 s limit, then the rest loads in the background) | `lib/core/offline_voice/offline_engines.dart`, `lib/features/startup/startup_screen.dart` |
| Detailed image description is mocked (`USE_MOCK_API` default true; dashboard `describe-image` not built) | `lib/core/network/image_description_repository.dart` |
| Dashboard `GET /api/v1/models` route not built (static `models/manifest.json` works) | dashboard repo; `docs/api-contract.md` |
| Dashboard DB has no books yet (as of 2026-10-13) | dashboard |
| Dashboard privacy: drop personal columns, old personal data in git history (user decision) | `docs/database/open-questions.md` item 6, `05-current-status.md` |
| Release APK size: fat 252 MB, arm64 split 94 MB — install the split APK | `docs/specs/decisions.md` 2026-10-15 |
| TalkBack may speak typed password characters (outside app control) | decision 2026-10-13 |
| Hosting online (https server) planned, not set up | — |

## Low
| Issue / TODO | File(s) |
|---|---|
| Library sync across devices mocked (Phase 7) | `lib/core/library/library_sync_repository.dart` |
| SUS screen not built (table exists); WER calculator + hidden test screen built 2026-10-17 | `lib/core/db/migrations.dart`, `docs/specs/algorithms.md` |
| Phase 6D built 2026-10-17; the blur/dark/bright thresholds (`lib/config/image_quality_config.dart`) are unverified starting values: tune from the `[IMAGE QUALITY]` / `[OCR FALLBACK]` log lines on the tablet | `docs/thesis/algorithms.md` |
| EPUB images (6E Part B) not started | `docs/specs/library.md` |
| Unused tables `outbox`, `usage_logs`, `documents_legacy` (drops proposed) | `docs/database/proposed-changes.sql`, `open-questions.md` items 7–8 |
| Duplicate columns `users.remote_id` vs `users.server_id`; `library_items.book_id` TEXT vs server INT | `docs/database/open-questions.md` items 9, 11 |
| Old account-sync mock still in code | `lib/core/auth/account_sync_repository.dart` |
| Unused packages declared: `csv`, `audio_session` (no imports in `lib/`, checked 2026-10-15); `share_plus` is now used (Percy log export) | `pubspec.yaml` |
| eSpeak NG (GPL-3.0) inside sherpa-onnx's Android library; MMS Tagalog voice is CC-BY-NC — review before any public/commercial release | `tool/voice_models/README.md` |
| ElevenLabs agent/voice ids default in code (not secrets) for the developer-only option | `lib/config/env.dart` |
| Several tests are timing-sensitive under PC load; `flutter_tester` crashes at random on the dev PC | `tool/test_each.sh`, `docs/handoff/08-testing.md` |
