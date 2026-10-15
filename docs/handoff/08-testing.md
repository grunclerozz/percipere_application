# 08 — Testing

## Automated tests
- Layout: `test/core/<module>/` (logic), `test/features/` (screens and flows with the whole app),
  `test/app/`, `test/android_release_rules_test.dart` (fails if the ML Kit R8 keep rules in
  `android/app/proguard-rules.pro` are removed), helpers in `test/helpers/`
  (`fakes.dart` with `TestEnv`, `FakeTts`, `FakeSpeechInput`…; `pump_app.dart`;
  `fake_model_source.dart`).
- **Full run on the dev PC:** `bash tool/test_each.sh` — runs each file alone and retries
  runner crashes (`flutter_tester` dies at random on this Windows PC: "did not complete",
  0xC0000005, "Connection closed before test suite loaded"). Last result (2026-10-15):
  **81 files, 981 tests, 0 failures** (about 1–1.5 h on this PC).
- Single file or folder: `flutter test test/core/voice/`.
- Always `flutter analyze` (must be clean) before reporting.
- Don't run tests and `flutter build` at the same time: test runs rewrite
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` with the dev-only
  `integration_test` plugin and the release build fails to compile.

## Tests that need extra setup (skipped by default)
| Test | Needs |
|---|---|
| `test_live/books_live_test.dart` | running dashboard with its test books; `PERCIPERE_LIVE_API`, `PERCIPERE_LIVE_HIDDEN_ID` |
| `test_live/accounts_reports_live_test.dart` | running dashboard; `PERCIPERE_LIVE_API`, optional `PERCIPERE_MAIL_LOG` (where emailed codes are read) |
| `test/core/offline_voice/real_models_test.dart` | `PERCIPERE_MODELS` (folder with the 3 model archives); on Windows `SHERPA_DLL_DIR` = the `sherpa_onnx_windows-<ver>/windows` folder in the pub cache (Windows' own older `onnxruntime.dll` shadows it otherwise) |
| `test/core/percy/intent_classifier_test.dart` | nothing extra; re-run after retraining Percy (checks Dart vs Python test vectors) |

## Slow or flaky
- Random `flutter_tester` crashes (above) — handled by `tool/test_each.sh`.
- Timing-sensitive tests can fail when the PC is busy (emulator, builds); fixed ones in
  `test/core/offline_voice/` now wait on conditions. Rerun a failing file alone before
  investigating.
- `test/features/reader/reader_flow_test.dart` was reported by the user as hanging on Windows.
  **Unverified:** it passed on the first attempt in both full runs on 2026-10-15. If it hangs,
  run it alone with a timeout and check for timers or `pumpAndSettle` on an animation that
  never settles (the listening animation never settles; tests use fixed `pump` steps).

## Manual tests (tablet; the user runs them)
- General checklist, every round: `docs/testing/system-test-checklist.md` (sections 1–18,
  result log; §17 voice/offline/noise, §18 offline voice without installing anything).
- First test with the real dashboard: `docs/testing/first-tablet-test.md`.
- Feature checklists: `phase-6b`, `phase-6c`, `phase-6e`, `input-fix`, `voice-response`,
  `voice-speed-voice`, `server-accounts`, `library-web`, `percy-local`, `assistant`
  (all in `docs/testing/`).
- Native-plugin changes: install the release APK on the emulator `Percipere_Light` and try one
  input of each kind (rule from 2026-10-07).

## Evaluation instruments (thesis)
| Instrument | State |
|---|---|
| **SUS** (System Usability Scale, 10 items) | Table `sus_responses` exists (migration v1); no screen or scoring code yet (Phase 7) |
| **WER** (word error rate, Levenshtein) | Table `wer_results` exists; no in-app calculation (Phase 6D, `docs/specs/algorithms.md`). WER was measured offline for model choice with `tool/voice_models/fleurs_eval.py` |
| Voice accuracy table | `docs/testing/system-test-checklist.md` §5 and §18 (understood / wrong action / nothing) |
| Percy metrics | accuracy, macro F1, cross-validation, confidence bands in `data/percy/reports/report-<date>.md` |
| **Likert** questionnaire | **Not found** in this repo (unverified; may live in the thesis manuscript) |
