# Worklog

**Append-only, newest first.** One entry per task, added at the end of the task
(`docs/agent-rules.md` §1). Never edit or delete old entries; correct them with a new entry.
Entries before 2026-10-15 were reconstructed from git history and `docs/specs/decisions.md`.

Format:
```
## YYYY-MM-DD — <short title>
- Agent: Claude Code | Codex
- Branch: <branch>
- Changed: <what, with file paths>
- Checks: <analyze / tests / build results, or "docs only: analyze">
- Commit: <hash> (pushed: yes/no)
- Follow-ups: <what is left, who does it>
```

---

## 2026-10-19 — Fixed dashboard address, Maglarawan online first, object counting
- Agent: Claude Code
- Branch: `feat/online-describe-counting` (on top of `41d5b43`)
- Changed: address fixed at build time (`lib/config/env.dart`, `core/network/server_address.dart`, `bootstrap.dart`, `android/app/build.gradle.kts` default cleartext host; removed `server_address_dialog.dart`, setting row, pref key, ARB strings, `USE_MOCK_API`). New `core/describe/vision_availability.dart`, `OnlineImageDescriber` in `image_describer.dart`, rewritten `image_description_repository.dart` (`POST /api/v1/describe`, anonymous), `uploadMaxSide` 1280. Controller: source label, consent offered after the first offline description, `_fetchOnline`. New `object_detector.dart`, `object_counting.dart`, `config/count_words.dart`; plugin `google_mlkit_object_detection ^0.17.1`. ARB fil/en. Tests: new `online_image_describer_test.dart`, `object_counting_test.dart`, `server_address_test.dart`; updated describe controller/flow, image prep, fakes. Docs 01, 02, 04, 05, 06, 07, 09, connection guide, defense checklist.
- Checks: `flutter analyze` no issues. `bash tool/test_each.sh`: 101/102 files pass, 1164 tests; `library_details_flow_test.dart` fails ("Collections rename and delete", `FakeSpeechInput.hear` null check) and fails the same with my changes stashed. `flutter build apk --release` OK (256.4 MB). Nothing run on a device.
- Commit: see `git log` (pushed: no)
- Follow-ups: tablet test; object side uses file width (EXIF-rotated photos guessed); fix the pre-existing library_details_flow failure.

## 2026-10-18 — Voice: half-duplex turns, room calibration, mic pre-roll, tone player, debug overlay
- Agent: Claude Code
- Branch: `feature/no-email-profiling-describe` (on top of `d7a9920`)
- Changed: new `lib/core/voice/mic_turn.dart` (turn state machine + watchdog); `voice_controller.dart` (turns,
  guard after speech, tone mute, watchdog close, screen change / app pause cleanup, room calibration, speech
  threshold, voice-detector speech holds back instructions, overlay data); `noise_monitor.dart` (calibration,
  baseline, speech threshold, overlay fields); `speech_input.dart` + `hybrid_speech_input.dart` (`muteAudio`,
  `releaseMic`, `measureRoom`, `ListenRequest.speechThreshold`); `offline_listener.dart` (mic lingers 1.5 s
  between silent sessions and feeds the next one, mute, threshold gate, `measure`); `hybrid_tts_service.dart`
  (quick Android failure retried once before switching); `announcer.dart` (output voice for the overlay);
  `earcon.dart` (`stop`, awaits the tone end); new `TonePlayer.kt`, `MainActivity.kt` (no `ToneGenerator`, stop
  on pause); `voice_config.dart` (new values; `voiceCommunication`, AGC on, `noiseSustain` 2 s,
  `audioFocusRelease` 250 ms); `startup_tasks.dart` (warm-up calibration); overlay + `voice_activity.dart` +
  `setting_items.dart` (debug builds too); ARB fil/en + l10n (5 overlay strings). Tests: new
  `test/core/voice/voice_turns_test.dart` (29); updated `engine_selection_test.dart`, `voice_capture_test.dart`,
  `voice_reliability_test.dart`, `phase6_flows_test.dart` (one more Settings row in debug builds),
  `test/helpers/fakes.dart`. Docs 03/05/06/07.
- Checks: `flutter analyze` no issues. Changed-area tests file by file (core voice ×12, offline_voice engine
  selection, accessibility ×4, tts ×3, settings, percy clips/settings/session, startup, voice/voice check/smart
  voice/percy/tutorial/tutorial-first/screens/assistant/phase6 flows, reader ×4): all pass (runner crashes
  retried). Full suite **not run**. `flutter build apk --release` OK (253.3 MB; compiles `TonePlayer.kt`).
  Emulator check not possible (no AVD on the PC). Nothing run on the tablet.
- Commit: `6b1eab7` (pushed: no)
- Follow-ups: user's tablet test (checklist in the report); `speech_to_text` can't get AEC/NS/AGC or pre-roll
  (own recognizer bridge = ask first); tune `speechMargin` / AGC from the log.

## 2026-10-18 — No-email registration, name spelling, text size loop, loading animation, ImageDescriber
- Agent: Claude Code
- Branch: `feature/no-email-profiling-describe` (from `main` `9244954`)
- Changed: (1) removed `verify_email_screen.dart` and `reset_password_screen.dart`, the `verify`/`resend`/`forgotPassword`/`resetPassword` API and service methods, routes and ids; `AccountApi.register` returns `RegisterStatus`; `AccountService.register` returns `RegisterResult` and tries a login at once; phone-only accounts moving to the server log in directly; Register says "Nagawa na ang iyong account. Subukan mong mag-log in." and goes to Login if the login fails; "Nakalimutan ang password" hidden for web app accounts (voice says "hindi pa available"); `serverErrorText` moved to `server_error_text.dart`. (2) `core/auth/name_spelling.dart` + `VoiceForm` spelling confirmation for name fields. (3) `TextSize.change`, `_changeSize` loop, buttons, new sample sentence in `profiling_screen.dart`. (4) `core/widgets/pulsing_logo.dart` on `startup_screen.dart`. (5) `core/describe/image_describer.dart`, rewritten `label_description.dart`, `config/image_label_groups.dart`, `LabelResult.count`. ARB strings added/removed (fil + en). Docs 02, 04, 05, 06, 07, `specs/profiling.md`.
- Checks: `flutter analyze` no issues. Changed-area tests file by file (features, core/auth, describe, widgets, app, settings, accessibility): all pass except `test/features/library/library_flow_test.dart`, which crashes the test runner every time **on `main` too** (not caused by this branch; assertions never failed). Full suite and release build **not run**; nothing run on the tablet or emulator.
- Commit: `fadc559` (pushed: no)
- Follow-ups: user decides on counts (ML Kit object detection plugin) and on spelling emails back; register reply shape unverified; web app password reset not available; tablet tests (see 05).

## 2026-10-18 — Percy answers questions (knowledge base) + voice clip handoff
- Agent: Claude Code
- Branch: `feat/percy-knowledge` (from `main` `9dcdfa7`), merged into local `main`
- Changed: **Percy ElevenLabs voice: ready, waiting for clips from teammate.** New `assets/percy/knowledge.json`
  (32 topics, ~30 example questions each, Filipino po/casual + English answers with a follow-up);
  `lib/core/percy/knowledge_base.dart` (own TF-IDF + cosine retrieval); `DialogueManager._askedQuestion`
  (ask_question intent or a near-exact question; answer >= 0.55, ask back 0.35-0.55, else three example
  questions; thresholds in `percy_config.dart`); new `PercyIntent.askQuestion`, `TurnOutcome.knowledge`,
  `PercyReply.topic`; `IntroRule` removed; three new dialogue lines in `responses.json`; brain/controller load
  the knowledge file (Percy still works if it fails). Dataset: +993 `ask_question` rows ("Generated (Claude)"),
  `sino ka`-type rows moved from `greeting`, `tulungan mo ako` and `hindi ko alam ang gagawin` moved from `help`;
  `validate_dataset.py` knows the intent and the new source. Provisional retrain (`train.py --provisional`):
  team test set (58 sentences) accuracy 0.966 -> 0.914, macro F1 0.971 -> 0.939; `ask_question` has no team test
  sentences yet. Voice: `generate_percy_voice.py` reads the knowledge answers and has `--check`; dry run 590 lines
  (333 fil, 257 en), 23,762 characters; Settings > Percy count includes the answers; `docs/percy-voice-handoff.md`
  for the teammate. Docs: `docs/thesis/algorithms.md` section 5, handoff 03/05/07. Tests: new
  `test/core/percy/knowledge_test.dart`; updated dialogue manager and session tests.
- Checks: `flutter analyze` no issues. Changed-area tests file by file: `test/core/percy/*` (6 files),
  percy_analysis_panel, percy_flow, startup_screen, report_issue (2), assistant_flow all pass. Full suite and
  release build **not run** (the task asked for analyze + changed-code tests only; no native change).
  Leave-one-out retrieval accuracy 87.8 % of 345 held-out questions.
- Commit: `12f7880` on `feat/percy-knowledge`, merged into local `main` (pushed: branch only, not `main`)
- Follow-ups: teammate runs the handoff steps and pushes `assets/percy/voice`; team writes real test questions
  for `ask_question` (then rerun `train.py` for the official score); tablet test of the answers.

## 2026-10-17 — Controls tutorial first (before Welcome)
- Agent: Claude Code
- Branch: `feat/tutorial-first` (from `main` `b7b035a`), not merged
- Changed: tutorial opens after the loading screen / voice download and **before Welcome** on the first launch:
  `lib/core/auth/session.dart` (`initialTutorialSeenProvider`, default true), `lib/app/bootstrap.dart` (reads
  `PrefKeys.tutorialDone` at device scope), `lib/app/router.dart` (no session + not seen -> `/tutorial`; saved
  session and expired session as before), `lib/features/setup/profiling_screen.dart` (goes straight to Home, no
  tutorial redirect). Skip rule in `lib/features/tutorial/tutorial_screen.dart` + `lib/config/tutorial_config.dart`
  (`firstStepMinSpoken` 5 s, `firstStepTimeout` 60 s): on first launch the two-finger swipe, "laktawan"/"skip", the
  button (hidden) **and the double-tap / wrong-try auto-advance on step one** are ignored until Percy's intro was
  spoken >= 5 s; the timeout opens it and logs `[TUTORIAL] skip allowed: safety timeout`; replay is unlocked from the
  start. No new ARB strings. The tutorial needs no account (device-scope prefs, speech language, command bus).
  Tests: new `test/features/tutorial_first_test.dart` (16: start locations incl. loading + voice setup chains,
  seen/expired/saved session, first-launch skip/swipe/voice/button/double-tap/wrong tries ignored, timeout + log,
  heard -> skip/advance -> Welcome + device flag, replay from Settings returns to Settings); updated
  `tutorial_flow_test.dart` (replays via `extra: true`) and `profiling_flow_test.dart` (ends on Home). Docs 02/05/06/07,
  checklist `docs/testing/tutorial-first-checklist.md`.
- Checks: `flutter analyze` clean. Changed-area tests file by file (own loop with crash retries; `tool/test_each.sh`
  takes no file list and would run the whole suite): 18 files pass (auth, welcome, setup/profiling, tutorial,
  screens/layout, startup, offline voice setup, voice understanding/ptt, smart voice). Full suite not run.
  `flutter build apk --release` OK (JDK 17 reachable; 252.8 MB; also compiles `AudioBridge.kt`). Not run on a device.
- Commit: `c4135c7` (pushed: no)
- Follow-ups: tablet test `docs/testing/tutorial-first-checklist.md`; first launch **without voice models**
  (with and without internet) is **unverified**: the download screen comes first, then the tutorial; voice then depends
  on Android's recognizer. A returning user who logged out may see the tutorial once (accepted).

## 2026-10-17 — Voice capture: half-duplex, noise floor, push-to-talk capture, one output voice
- Agent: Claude Code
- Branch: `fix/voice-capture` (from `main` `b751007`), now on `main` (see Commit)
- Changed: root causes + fixes in `docs/handoff/03-voice-and-percy.md` → "Voice capture and one output
  voice". New `lib/core/voice/noise_monitor.dart` (`NoiseMonitor`, `VoiceCaptureStatus`);
  `voice_controller.dart` (half-duplex start guard, no barge-in, noise floor, noisy vs uncertain,
  push-to-talk keeps listening through Android's own session ends, no partial runs while held);
  `speech_input.dart` (`ListenRequest.pushToTalk`, `onSpeechStart`), `hybrid_speech_input.dart`,
  `offline_listener.dart` (push-to-talk mode, `MicCapture`), `command_recognizer.dart` (whole-hold
  decode with 0.5 s pre-roll), `AudioBridge.kt` (audio source choice + fallback, effects reported,
  focus leak fixed), `hybrid_tts_service.dart` (one route per language, logged switches),
  `tts_service.dart` (rate + pitch every utterance, stop on no answer), `announcer.dart` +
  `command_bus.dart` + `percy_controller.dart` + `percy_clips.dart` (clips only for whole Percy lines),
  `voice_state_overlay.dart` + ARB fil/en (source and noise lines), `setting_items.dart` (barge-in row
  hidden), `voice_config.dart`. Tests: new `test/core/voice/voice_capture_test.dart`; updated
  `engine_selection_test.dart`, `percy_clips_test.dart`, `voice_reliability_test.dart`,
  `voice_response_test.dart` and `reader_controller_test.dart` (barge-in tests skipped while
  half-duplex is on), `test/helpers/fakes.dart`. Docs 03/05/06/07. No `voice_log.txt` existed.
- Checks: `flutter analyze` clean. Changed-area tests file by file (core voice, offline_voice, percy,
  accessibility, settings, tts, gestures, features reader/settings + voice/Percy/startup/tutorial/
  assistant/screens/auth flows): 42 files; after fixing 1 code bug (push-to-talk wait timer) and 2
  outdated tests, the failed files and all of `test/core/voice` pass again (187 tests in the last
  rerun). **Release build NOT done**: started, stopped by Claude Code because the PC ran low on
  memory. Full suite not run (as asked). Kotlin change not compiled yet.
- Commit: `11b65f8`, directly on `main` (pushed: no). Another process switched the working copy to
  `docs/database-masterlist-v3` and merged it into `main` (`a922881`) while this work was uncommitted, so the
  commit landed on `main` without a merge commit; `fix/voice-capture` now points at `11b65f8`
- Follow-ups: user builds the release APK (this also compiles `AudioBridge.kt`) and runs the tablet
  tests (quiet, TV on, Percy talking → hold, reading → hold, airplane mode); send `[VOICE …]`,
  `[TTS] …`, `[OFFLINE VOICE] microphone:` lines if problems remain.

## 2026-10-17 — Percy's ElevenLabs voice from bundled clips
- Agent: Claude Code
- Branch: `feat/percy-elevenlabs` (from `main`), merged into `main`
- Changed: `tool/percy_voice/` (generator, README, ARB key list), `assets/percy/voice/manifest.json`
  (empty), `.gitignore` (.env), `lib/core/percy/percy_clips.dart` (hash key, manifest, `PercyClips`,
  providers), `percy_responses.dart` (`fixedSentences`), `announcer.dart` (clip first, offline voice
  fallback, stop covers the clip), `bootstrap.dart`, `AudioBridge.kt` (`playClip`: mp3 decode + rate),
  Settings row "Boses ni Percy" (`setting_items.dart`, ids, ARB fil/en), `pubspec.yaml` asset folder,
  test `test/core/percy/percy_clips_test.dart`. Details in `03-voice-and-percy.md`.
- Checks: `flutter analyze` clean; changed-area tests (accessibility, percy, settings, voice, reader) pass;
  debug APK builds (Kotlin compiles); release build NOT run. The generator was run only with `--dry-run` (no API call, no key).
- Commit: see `git log` (pushed: no)
- Follow-ups: **user runs the generator** (README), listens to a few clips, commits `assets/percy/voice/`;
  tablet test of clip playback, speed, push-to-talk stop; release build + emulator check of `playClip`.

## 2026-10-17 — Voice at startup / after upload, loading screen, push-to-talk
- Agent: Claude Code
- Branch: `fix/voice-startup-ptt` (from `main` `df31ebe`; `fix/voice-reliability` merged in first because the
  tablet results came from it — only `05`/worklog conflicted), merged into `main`
- Changed: root causes + fixes in `docs/handoff/03-voice-and-percy.md` → "Startup loading screen, busy phases,
  push-to-talk". New `lib/features/startup/startup_screen.dart`, `lib/core/startup/startup_tasks.dart`,
  `lib/config/startup_config.dart`, `lib/core/voice/voice_readiness.dart`, `lib/core/voice/voice_activity.dart`,
  `lib/core/widgets/voice_state_overlay.dart`; `voice_controller.dart` (set-up retry, busy failures not counted,
  push-to-talk, wait for speech to stop), `announcer.dart` (`stopAndWait`), `offline_speaker.dart` +
  `hybrid_tts_service.dart` (stop returns at once), `offline_engines.dart` (`loading`), gestures
  (`holdRelease`, hold-only TalkBack mode, hold 450 ms), `nav_intent.dart` (`listenRelease`), `command_bus.dart`,
  Reader (processing busy, no auto-read over a hold), router/bootstrap/main (loading route, launch clock),
  developer setting "Estado ng boses", ARB fil/en (new strings + push-to-talk wording in tutorial/help),
  `.gitignore` (`voice_log.txt`). Tests: new `test/core/voice/voice_startup_ptt_test.dart`,
  `test/features/startup_screen_test.dart`, `test/features/reader/reader_hold_test.dart`, classifier tests.
  Docs 03/05/06/07, `docs/testing/voice-startup-ptt-checklist.md`. No `voice_log.txt` existed.
- Checks: `flutter analyze` clean. Changed-area tests, one clean run file by file: 43 files, 530 tests, 0 failures
  (an earlier run was invalid: an orphaned runner overlapped it). `reader_hold_test` checked to fail with the
  fix disabled. **Release build NOT done**: started (a JDK is present now) but stopped by Claude Code because the
  PC ran low on memory. Full suite not run. **Cold-start load time not measured**: no `Percipere_Light` AVD on
  the PC any more; the app logs/shows it.
- Commit: `fc2a5cc` on the branch, merge `87ddbaa` into `main` (pushed: no)
- Follow-ups: user builds the release APK and runs `docs/testing/voice-startup-ptt-checklist.md`, reports the
  load time; ML Kit main-thread photo decode left as is (06); TalkBack push-to-talk path unverified.

## 2026-10-17 — Final check and defense prep (A5)
- Agent: Claude Code
- Branch: `main`
- Changed: new `docs/defense-checklist.md`, `docs/demo-script.md`; `docs/testing/system-test-checklist.md`
  §19 (short final tablet round) + result-log row; status board updated.
- Checks: `flutter analyze` clean. 520 tests in the changed areas (algorithms, ocr, extraction, network,
  settings, accessibility, voice, percy, offline_voice, describe, db, report, camera, settings screens,
  voice/Percy flows, WER screen, release rules) pass; one runner crash ("did not complete") on
  `wer_test_screen_test.dart` passed on rerun. Secrets scan of tracked files: none found (only test
  fixture passwords). **Release build NOT done**: `JAVA_HOME` points to a missing Android Studio JDK and
  no JDK exists on this PC; build it yourself. Full suite not run (as the prompt says).
- Commit: see git log (pushed: no)
- Follow-ups: **`fix/voice-reliability` (A2: say-twice / hold-twice / false "not available") is NOT merged
  into `main`** (2 commits, `f4a1a65`, `efb1eee`); the checks above therefore do not cover it. Merge it
  (user's call), then rerun the voice tests. Fix the JDK path, build the release APK with the demo
  `--dart-define`s, run §19.

## 2026-10-17 — App connection for the defense (A4)
- Agent: Claude Code
- Branch: `chore/app-connection`
- Changed: `Env.allowsCleartext` now also allows private-network hosts and localhost
  (`lib/config/env.dart`); new `lib/core/network/server_health.dart` +
  `lib/features/settings/server_connection_test.dart` (dev Settings row "Subukan ang koneksyon sa
  server", `GET /api/v1/health`, spoken reasons); image description now follows the saved server
  address and uses `apiDio()` (`image_description_repository.dart`); Aklatan says whether the
  server answered (`library_screen.dart`); ARB strings fil/en; `docs/connection-guide-app.md`;
  `docs/handoff/04` audit. Dashboard not touched (read only).
- Checks: `flutter analyze` clean; changed-area tests, see the report. Release build not run (no JDK
  in the agent session).
- Commit: see git log (pushed: no)
- Follow-ups: dashboard lacks `GET /api/v1/models` and `POST /api/describe-image`; health reply has
  no server version; test on the real tablet + MacBook (MAMP) before the defense.

## 2026-10-17 — Phase 6D algorithms (A3)
- Agent: Claude Code
- Branch: `feat/algorithms` (merged into `main`)
- Changed: new `lib/core/algorithms/{wer,image_quality,otsu}.dart`, `lib/core/ocr/ocr_fallback.dart`,
  `lib/config/{image_quality_config,wer_phrases}.dart`, `lib/core/db/daos/wer_dao.dart`,
  `lib/features/settings/wer_test_screen.dart` (hidden, `PERCIPERE_DEV` Settings row + route
  `/settings/wer-test`); camera capture check in `lib/features/camera/camera_screen.dart`
  (tip + retake offer, 30 s expiry); Otsu fallback wired in `document_extractor.dart` (images the
  Reader reads; not the Maglarawan picture); ARB strings (fil first) + regenerated l10n;
  `docs/thesis/algorithms.md` (4 algorithms + tools not developed by us). Docs 02, 06, 07, 08 updated.
- Checks: `flutter analyze` clean. 34 changed-area test files pass (algorithms, ocr, extraction,
  settings, db, voice, camera, describe, reader, capture flows, WER screen). A first run caught a
  real regression (camera tests hung reading a missing fake photo); fixed with an `existsSync`
  guard and re-run green. Full suite NOT run. **Release build NOT run**: `JAVA_HOME` points to a
  missing Android Studio JDK in the agent session; run `flutter build apk --release` yourself.
- Commit: see git log (pushed: no)
- Follow-ups: tablet tuning of thresholds (unverified); Percy results in the thesis doc are
  still provisional (a6); `fix/voice-reliability` is still not merged into `main`.

## 2026-10-17 — Voice reliability: say twice, hold twice, false "not working", noise
- Agent: Claude Code
- Branch: `fix/voice-reliability` (from `main` `df0a3df`)
- Changed: root causes and fixes in `docs/handoff/03-voice-and-percy.md` → "Voice reliability".
  `lib/core/voice/voice_controller.dart` (done-before-error wait, stale events, sound-based
  dead-recognizer check, give-up grace, tone on mic live, one hold = one session, noise judgement),
  `lib/core/voice/speech_input.dart` (recognizer settle), `lib/core/offline_voice/offline_listener.dart`
  (serialized mic, cancel during start, absolute level), `command_recognizer.dart` (warm-up),
  `hybrid_tts_service.dart` + `lib/core/tts/tts_service.dart` (sticky stop), `AudioBridge.kt`
  (NoiseSuppressor/AGC flags), `lib/core/accessibility/command_bus.dart` (`handleUtterance(noisy:)`),
  `lib/config/voice_config.dart`, ARB (`voiceNoisyDidYouMean`, `voiceTrial*`), new
  `lib/core/voice/voice_trial.dart` + developer rows in `voice_check_screen.dart` (20-command CSV test);
  tests `test/core/voice/voice_reliability_test.dart` (new), `engine_selection_test.dart`,
  `voice_controller_test.dart` (late result now kept), `voice_cutoff_test.dart` (tone waits for the mic),
  `test/helpers/fakes.dart`; docs 03/05/06/07, `docs/testing/voice-reliability-checklist.md`.
- Checks: `flutter analyze`: no issues. Problems 2–3 reproduced: 3 of the new tests fail on the old
  code and pass now. Changed-code tests: 15 files / 214 tests passed, then the 4 voice files again
  after the last edit (62 passed). Full suite and emulator not run (as asked). Release build NOT run:
  the JDK path from `flutter doctor` was not reachable from the agent session.
- Commit: `f4a1a65` (pushed: no). Merge into `main` not done: blocked by the agent's permission check.
- Follow-ups: user merges `fix/voice-reliability` into `main`, builds the APK, runs
  `docs/testing/voice-reliability-checklist.md` and sends the CSV + logs; tune noise thresholds from it.

## 2026-10-17 — Merge finished branches into main
- Agent: Claude Code
- Branch: `main`
- Changed: merged `feat/voice-hold-interrupt` (which contains `feat/percy-smarter`) into
  `main`, then merged `docs/database-masterlist-v2` (which contains `docs/database-masterlist`)
  into `main`. Both merges were clean — no conflicts, confirmed first with `git merge-tree`.
  This brings in: Percy smarter (provisional retrain), voice hold-to-interrupt + false-error
  fix, offline voice engines, the shared `docs/agent-rules.md`/`AGENTS.md` restructuring, and
  the database masterlist v2 docs. `docs/database-masterlist`, `docs/database-masterlist-v2`,
  `feat/percy-smarter` and `feat/voice-hold-interrupt` are all now fully contained in `main`
  (not deleted, in case the user wants to keep them around). Also: found `tool/voice_models/`
  (82 MB of downloaded model `.tar.gz` archives the user had pulled locally) untracked and
  added `tool/voice_models/dist/` to `.gitignore` so those binaries are never committed.
  Updated this worklog and `docs/handoff/05-current-status.md`.
- Checks: `flutter analyze`: no issues. `test/core/{percy,voice,settings,accessibility}` (15
  files): all pass when run file-by-file (the known random `flutter_tester` crash hit
  `percy_settings_test.dart` once in a combined run; it passes alone and on retry — this PC's
  known issue, see `docs/handoff/09-environment.md`). Full suite, release build and emulator
  not run (not required for a merge task; no native-plugin code was added by this task itself).
- Commit: `fd2dd21` (merge of `feat/voice-hold-interrupt`), `d306cac` (merge of
  `docs/database-masterlist-v2`), plus a docs/`.gitignore` follow-up commit (pushed: no)
- Follow-ups: user's tablet test (all the items already waiting in the table above); user
  decides whether to delete the now-merged branches; user uploads the voice model archives.

## 2026-10-17 — Database masterlist v2 (read-only analysis)
- Agent: Claude Code
- Branch: `docs/database-masterlist-v2` (from `feat/voice-hold-interrupt`)
- Changed: new `docs/database/masterlist.md` and `docs/database/masterlist.xlsx` (11 sheets). Built from the live
  MySQL `percipere_dashboard` (structure + row counts only; schema v13), the dashboard code on
  `feat/admin-roles`, and the real SQLite migrations v1–v7 run in SQLite. Contains table/column dictionaries,
  enums, three Mermaid ERDs (MySQL, SQLite, app↔server through the API), data flow/privacy (RA 10173),
  changes since the 2026-10-13 masterlist, and a findings list (nothing fixed). The old
  `database-masterlist.*` files are untouched. No code, schema, data or dashboard file was changed.
- Checks: docs only: `flutter analyze`: no issues found. Mermaid syntax checked with the Mermaid parser in the browser pane.
- Commit: `f88422e` (pushed: no)
- Follow-ups: the user decides on the findings (S-1 … X-1 in section 9), e.g. legacy `members` columns, missing
  admin foreign keys, unused Android tables, erasure of reports when an app user is deleted.

## 2026-10-16 — Voice: hold to listen, false-error fix (Phase B)
- Agent: Claude Code
- Branch: `feat/voice-hold-interrupt` (from `feat/percy-smarter`)
- Changed: `lib/core/offline_voice/hybrid_speech_input.dart` (ignore Android errors during an offline
  session), `lib/core/voice/voice_controller.dart` (`_giveUp` closes the session),
  `lib/config/voice_config.dart` + `lib/core/gestures/gesture_map.dart` (`holdToListen`),
  `lib/core/gestures/gesture_surface.dart` (TalkBack custom action), ARB + generated l10n
  (`gestureHoldListenAction`), `lib/core/percy/percy_controller.dart` + `command_bus.dart`
  (`interruptTurn`), tests in `test/core/{gestures,offline_voice,voice,percy}`, docs 03/05/06/07.
- Checks: `flutter analyze`: no issues. Changed test files + neighbours (gestures, engine_selection,
  voice_controller, voice_cutoff, voice_offline, percy_session): 85 passed. Full suite, emulator and
  release build NOT run (as agreed). Needs the tablet: hold while Percy/Reader speaks, TalkBack action,
  the false error in daily use.
- Commit: `33f11cc` (pushed: no)
- Follow-ups: Phase C (measure latency from tablet logs, noise options) after the user's review.

## 2026-10-16 — Percy smarter: PROVISIONAL retrain
- Agent: Claude Code
- Branch: `feat/percy-smarter`
- Changed: `scripts/percy/train.py` (`--provisional`: trains although new intents have no team test
  phrases; report marked PROVISIONAL); retrained and exported `assets/percy/model.json` (Logistic
  Regression, balanced, C 30), `model_alt.json` (Naive Bayes), `scripts/percy/test_vectors.json`;
  `data/percy/reports/report-2026-10-16.md` + confusion PNG; results in
  `docs/handoff/03-voice-and-percy.md` (PROVISIONAL section); status and known-issues updated.
  `docs/thesis/percy-evaluation.md` NOT written yet. Thresholds unchanged.
- Checks: `flutter analyze`: no issues. `flutter test test/core/percy test/core/settings test/core/voice
  test/core/accessibility`: 277 passed (the 3 stale-model tests now pass). Full suite and release build
  not run.
- Commit: `2ae0b31` (pushed: no)
- Follow-ups: team adds test phrases for the 5 new intents; rerun `train.py` (no `--provisional`);
  write the official docs. Note the old "before" score (1.000) is leaky and not a fair baseline.

## 2026-10-16 — Percy smarter: verify handoff, merge data, evaluation pipeline (retrain blocked)
- Agent: Claude Code
- Branch: `feat/percy-smarter`
- Changed: verified Codex's routing/normalization/set_speed work; removed 76 training rows that
  match `data/percy/test_team.csv` after normalization (58 Team + 18 Starter variants); added the
  570 reviewed rows to `data/percy/intents.csv` (source `Generated (Codex)`, 0 duplicates, 0 phrase
  in two intents); `scripts/percy/validate_dataset.py` (new intents, test-file loader, leakage and
  cross-intent checks, source shares) and `scripts/percy/train.py` (team-only test set is primary,
  70/15/15 + 5-fold CV secondary, NB vs LR with/without class weighting, data shares, 10
  most-confused phrases, test-set completeness gate, `--dry-run`); `assets/percy/responses.json`
  (action names for the 5 new intents); `ReportIssueRule` accepts "mag report" (STT spelling);
  `PercySlots.speed` ignores "mas/medyo mabagal/mabilis" (relative, not a preset); import order
  fixed (3 analyzer infos); tests for set_speed presets, relative wording, rate limits;
  corrected the `ano po pakisuyo nga` test to the agreed rule (keep original if nothing is left).
- Checks: `flutter analyze`: no issues. Percy + settings tests pass except 3 in
  `intent_classifier_test.dart` that need the retrained `model.json`/`test_vectors.json` (expected).
  Full suite and release build NOT run (no retrain yet, no native change).
- Commit: `e868ed7` (pushed: no)
- Follow-ups: **team** adds 8+ (about 10) phrases each for `describe_image`, `more_detail`,
  `read_image_text`, `tutorial`, `set_speed` to `data/percy/test_team.csv` (all 0 now) and decides
  `paano gamitin` (help vs tutorial). Then run `train.py`, write `docs/handoff/03-voice-and-percy.md`
  and `docs/thesis/percy-evaluation.md`, run all tests.

## 2026-10-16 — Shared Claude Code + Codex documentation
- Agent: Claude Code
- Branch: `docs/database-masterlist`
- Changed: new `docs/agent-rules.md` (single source of truth for rules and the shared
  workflow); `CLAUDE.md` and `AGENTS.md` shortened to pointers; status history moved from
  `CLAUDE.md` to `docs/handoff/05-current-status.md` (now the shared status board); "where
  things are written" index moved to `docs/handoff/01-architecture.md`; environment notes
  moved to `docs/handoff/09-environment.md`; `07-decisions.md` is now where decisions are
  recorded; `08-testing.md` corrected (Likert is in the thesis draft, no app feature); new
  this worklog.
- Checks: docs only — `flutter analyze`: no issues found. No tests or build (docs only).
- Commit: see `git log` ("docs: shared Claude Code + Codex documentation") (pushed: no)
- Follow-ups: user pushes when ready; Codex reads `AGENTS.md` → `docs/agent-rules.md` on its
  first run.

## 2026-10-15 — Codex handoff documentation
- Agent: Claude Code
- Branch: `docs/database-masterlist`
- Changed: `AGENTS.md`, `docs/handoff/01`–`09`.
- Commit: `55edf3c` (pushed: no)

## 2026-10-15 — Offline voice with the app's own engines
- Agent: Claude Code
- Branch: `docs/database-masterlist`
- Changed: sherpa-onnx offline commands (Whisper tiny Filipino + Silero VAD) and voices (MMS
  Tagalog, Piper English), first-launch download `/voice-setup`, model controls in Voice check
  (`lib/core/offline_voice/`, `AudioBridge.kt`, `tool/voice_models/`).
- Checks: full suite 81 files / 981 tests passed (per `docs/handoff/08-testing.md`).
- Commit: `3bb1627` (pushed: no)
- Follow-ups: user uploads the 3 archives + `manifest.json`; tablet test (checklist §18).

## 2026-10-14 — Voice regression fix, Voice check screen
- Agent: Claude Code
- Branch: `docs/database-masterlist`
- Changed: app-timed silences, listening plan, matcher extras, Voice check screen.
- Commit: `881dd1a` (pushed: no)
- Follow-ups: tablet test (checklist §17).

## 2026-10-14 — Database masterlist, ERDs
- Agent: Claude Code (commit has its co-author line)
- Branch: `docs/database-masterlist`
- Commit: `0e24bd8` (pushed: yes)

## Earlier (2026-10-01 – 2026-10-13)
See `docs/handoff/05-current-status.md` → "Recent commits by week" and "Status history".
