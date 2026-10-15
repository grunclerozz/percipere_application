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
| Percy dataset small (many intents 7–8 sentences); add team sentences and retrain | `data/percy/intents.csv`, `docs/percy-dataset-guide.md` |
| Offline recognizer gives no partial results → no reading pause while the user speaks over it | `lib/core/offline_voice/offline_listener.dart` |
| First prompt after app start can wait for the offline voices to load (emulator: 5–20 s) | `lib/core/offline_voice/offline_engines.dart` |
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
| SUS screen and WER calculation not built (tables exist) | `lib/core/db/migrations.dart`, `docs/specs/algorithms.md` |
| Phase 6D (Laplacian blur, Otsu) postponed | `docs/specs/algorithms.md` |
| EPUB images (6E Part B) not started | `docs/specs/library.md` |
| Unused tables `outbox`, `usage_logs`, `documents_legacy` (drops proposed) | `docs/database/proposed-changes.sql`, `open-questions.md` items 7–8 |
| Duplicate columns `users.remote_id` vs `users.server_id`; `library_items.book_id` TEXT vs server INT | `docs/database/open-questions.md` items 9, 11 |
| Old account-sync mock still in code | `lib/core/auth/account_sync_repository.dart` |
| Unused packages declared: `csv`, `audio_session` (no imports in `lib/`, checked 2026-10-15); `share_plus` is now used (Percy log export) | `pubspec.yaml` |
| eSpeak NG (GPL-3.0) inside sherpa-onnx's Android library; MMS Tagalog voice is CC-BY-NC — review before any public/commercial release | `tool/voice_models/README.md` |
| ElevenLabs agent/voice ids default in code (not secrets) for the developer-only option | `lib/config/env.dart` |
| Several tests are timing-sensitive under PC load; `flutter_tester` crashes at random on the dev PC | `tool/test_each.sh`, `docs/handoff/08-testing.md` |
