# 01 — Architecture

How the app is put together. Deeper notes per subsystem: `docs/specs/architecture.md`.
Full table/column reference: `docs/database/table-list.md`, `docs/database/database-masterlist.md`.

## Tech stack (moved from `CLAUDE.md` / `AGENTS.md`; from `pubspec.yaml` and the code)
- Flutter 3.47.5 (stable), Dart 3.13.4 (`environment: sdk ^3.13.4`). App version `0.1.1+2`.
- State: Riverpod 3 (`flutter_riverpod`, hand-written providers, **no codegen**). Routing: `go_router`.
- Storage: `sqflite` with versioned migrations; secrets/tokens in `flutter_secure_storage`.
- OCR `google_mlkit_text_recognition`; image labels `google_mlkit_image_labeling`; `camera`.
- Speech in: `speech_to_text` (Android recognizer) + `sherpa_onnx` (own offline command recognizer).
- Speech out: `flutter_tts` (Android TTS) + `sherpa_onnx` offline voices.
- Files: `file_picker` (SAF, no storage permission), `pdfrx`, `archive` + `xml` (DOCX/EPUB).
- Network: `dio`, `connectivity_plus`. Auth: `local_auth` (fingerprint), PBKDF2 hashing in Dart.
- ElevenLabs Android SDK (old Percy, developer-only, Kotlin bridge).
- Bundled fonts (no `google_fonts`).
- Android: minSdk 24, compileSdk 37, application id `ph.bataan.percipere.app` (was
  `ph.bataan.percipere` until 2026-10-07; Kotlin package and namespace unchanged).

## Folder structure
| Path | What is there |
|---|---|
| `lib/main.dart` | Entry point: runs `bootstrap()` then `PercipereApp` |
| `lib/app/` | `app.dart` (MaterialApp + hosts), `bootstrap.dart` (startup), `router.dart` (routes), `ids.dart` (screen/action ids), `locale_provider.dart`, `theme/` |
| `lib/config/` | `env.dart` (build flags), `voice_config.dart`, `percy_config.dart`, `palette.dart`, `constants.dart`, `image_labels_fil.dart` |
| `lib/core/accessibility/` | ActionRegistry, CommandBus, Announcer, focus, haptics, earcons, navigation mode |
| `lib/core/gestures/` | `gesture_surface.dart` → `gesture_classifier.dart` → `gesture_map.dart` |
| `lib/core/voice/` | Android speech input, `voice_controller.dart`, `command_matcher.dart`, `voice_commands.dart`, barge-in |
| `lib/core/offline_voice/` | App's own offline engines (sherpa-onnx), model download/store |
| `lib/core/tts/` | `tts_service.dart` (flutter_tts), chunker, language detector, reading rate/voice |
| `lib/core/percy/` | Self-built assistant: classifier, dialogue manager, slots, controller |
| `lib/core/assistant/` | Old ElevenLabs Percy (developer option only) |
| `lib/core/ocr/`, `lib/core/extraction/` | ML Kit OCR, text cleanup; PDF/DOCX extraction |
| `lib/core/describe/` | Maglarawan: on-device image labels → Filipino description |
| `lib/core/library/` | Aklatan models, EPUB parser, admin-book repositories, service |
| `lib/core/auth/` | Accounts (local + server), sessions, PBKDF2 hashing, lockout, biometrics |
| `lib/core/report/` | Report an Issue: model, local repository, HTTP API, retry sync |
| `lib/core/db/` | `app_database.dart`, `migrations.dart`, `daos/` |
| `lib/core/network/` | `api_dio.dart` (dio + `CleartextGuard`), connectivity, the fixed server address, image description repo |
| `lib/core/settings/`, `lib/core/platform/`, `lib/core/widgets/`, `lib/core/understanding/` | Settings model/controller; permissions, storage, system settings; shared widgets (Gesture Pad, Speaking Zone, speed strip…); document insights for Percy |
| `lib/features/<screen>/` | One folder per screen group: welcome, auth, setup, tutorial, home, capture, camera, upload, describe, reader, library, settings, report, offline_voice |
| `lib/l10n/` | `app_fil.arb` (template), `app_en.arb`, generated `app_localizations*.dart` |
| `assets/` | `percy/` (model.json, model_alt.json, persona.json, responses.json), `fonts/` |
| `android/app/src/main/kotlin/ph/bataan/percipere/` | `MainActivity.kt` (channels: storage, sound), `SpeechInfoBridge.kt`, `AudioBridge.kt`, `AssistantBridge.kt` |
| `test/`, `test_live/` | Unit/widget tests; live tests against a running dashboard (skipped by default) |
| `scripts/percy/`, `data/percy/` | Percy training (Python) and dataset/reports |
| `tool/` | `test_each.sh`, `voice_models/` (offline model build scripts + manifest) |
| `assistant/` | ElevenLabs agent config and Python tools (PC/server only) |
| `percipere/` | Stray old project, excluded — ignore |

## Startup
`lib/app/bootstrap.dart`: logs the build (`[CAPTURE]`), opens SQLite, restores the session
(secure storage), loads that account's settings, creates the offline engines and model store
(loads them if already downloaded), creates `HybridTtsService`, checks voices, reads the server
address and mic permission, and returns Riverpod overrides. `routerProvider` then picks the
first route: `/voice-setup` (first launch, models missing), else `AppRoutes.landing(account)`,
`/auth` (session expired) or `/` (Welcome).

## Input model: one action, three ways
- A screen wraps its UI in `AccessibleScreen` with a `ScreenRegistration`
  (`lib/core/accessibility/screen_registration.dart`): id, title, prompt, follow-up, help,
  `A11yAction`s (id, label, `voiceSynonyms`, confirmation, `onActivate`), intent handlers.
- `ActionRegistry` (`action_registry.dart`) holds the active registration
  (`activeScreenProvider`). `AccessibilityHost` announces the screen.
- **Gestures:** `GestureSurface` → `GestureClassifier` → `gestureMap` → `NavIntent` → `CommandBus`.
- **Voice:** `VoiceController` → recognizer text → `CommandBus.handleUtterance` →
  `CommandMatcher` (screen actions first, then app-wide `globalVoiceCommands`) → same action.
- **Taps:** widgets call `bus.activate(actionId)`.
- `CommandBus` (`command_bus.dart`) runs the action, speaks the confirmation through
  `Announcer`, plays haptics, handles yes/no offers ("oo" / double tap) and help.
- `Announcer` (`announcer.dart`) queues speech sentence by sentence, holds instructions after a
  question until the answer wait (6 s) ends, and hands off to TalkBack when it is on.

## Routes (`lib/app/router.dart`, `AppRoutes`)
`/` Welcome · `/tutorial` · `/register`, `/register/security`, `/register/fingerprint`,
`/register/verify` · `/login`, `/login/forgot`, `/login/reset`, `/login/legacy` ·
`/account/upgrade` · `/auth` (log in again?) · `/setup` (profiling) · `/home` (base of the back
stack) · `/capture` · `/camera` · `/describe/source`, `/describe` · `/reader` · `/settings`,
`/settings/voice-check` · `/library`, `/library/item`, `/library/favorites`, `/library/chapters` ·
`/report`, `/report/mine` · `/voice-setup` (first-launch model download).

## State management
Riverpod 3 with hand-written `Provider` / `Notifier` / `NotifierProvider` (no codegen).
Startup values are injected as overrides from `bootstrap()` (e.g. `ttsServiceProvider`,
`initialSettingsProvider`, `offlineEnginesProvider`, `modelStoreProvider`). Tests override the
same providers with fakes (`test/helpers/fakes.dart`, `TestEnv`).

## Database (SQLite, `lib/core/db/`)
Schema version **7** (`Migrations.latestVersion`). Each migration is a new `Migration` in
`migrations.dart`; never edit an old one.

| Version | Change |
|---|---|
| v1 | Initial schema: `users`, `preferences`, `documents`, `usage_logs`, `outbox`, `sus_responses`, `wer_results` |
| v2 | Email + password accounts (Phase 6B), `login_attempts` |
| v3 | Image descriptions in history (Phase 6C): `documents` rebuilt with source type `description` + thumbnail |
| v4 | Library replaces Reading History (Phase 6E): `library_items`, `library_favorites`, `library_collections`, `library_collection_items`; old documents kept as `documents_legacy` |
| v5 | `percy_turns` (Percy log for retraining) |
| v6 | `issue_reports` (Phase 10) |
| v7 | `issue_reports.server_status` (ticket status from the dashboard) |

DAOs: `daos/preferences_dao.dart` (key/value settings per user or device, `PrefKeys`),
`daos/library_dao.dart`, `daos/percy_log_dao.dart`. Unused tables (kept, marked deprecated in
`docs/database/`): `outbox`, `usage_logs`, `documents_legacy`; `sus_responses` and
`wer_results` exist but no code writes them yet.

Files outside SQLite: downloaded books and covers (`lib/core/library/library_paths.dart`),
offline voice models in app support storage `voice_models/` (`ModelStore`), sign-in token and
session in `flutter_secure_storage`.

## Repositories: real vs mock
| Interface | Real | Mock / fallback | Chosen by |
|---|---|---|---|
| `AccountApi` (`core/auth/account_api.dart`) | `HttpAccountApi` | phone-only accounts | `Env.accountServer` (on when `API_BASE_URL` set) |
| `AdminBookRepository` (`core/library/`) | `HttpAdminBookRepository` | `UnconfiguredBookRepository` (no server); `FakeAdminBookRepository` is test-only | `API_BASE_URL` |
| `IssueReportApi` (`core/report/issue_report_api.dart`) | `HttpIssueReportApi` | none (reports stay pending) | `API_BASE_URL` |
| `ImageDescriptionRepository` (`core/network/`) | `HttpImageDescriptionRepository` (`POST /api/v1/describe`) | none (the describer falls back to ML Kit); `FakeDescriptionRepository` is test-only | `API_BASE_URL` (the mock and `USE_MOCK_API` were removed 2026-10-19) |
| `LibrarySyncRepository` (`core/library/`) | — | `MockLibrarySyncRepository` | always mock (Phase 7) |
| `AccountSyncRepository` (`core/auth/`) | — | `MockAccountSyncRepository` | old design, unused by server accounts |
| `ModelSource` (`core/offline_voice/model_installer.dart`) | `HttpModelSource` | built-in GitHub list | dashboard reachable or not |

## Speech engines (summary; details in `03-voice-and-percy.md`)
- `speechInputProvider` = `HybridSpeechInput`: commands → app's offline recognizer when
  loaded, else Android `SttSpeechInput`; dictation and Percy → Android.
- `ttsServiceProvider` = `HybridTtsService`: installed Android voice → app's offline voice →
  Android (maybe network) voice.

## Where specs, checklists and guides are (moved from `CLAUDE.md` on 2026-10-16)
- Rules and workflow for agents: `docs/agent-rules.md`. Status: `docs/handoff/05-current-status.md`.
- `docs/specs/architecture.md` — how the existing subsystems work (**read before changing one**).
- `docs/specs/decisions.md` — dated decision log (long form); summary in `docs/handoff/07-decisions.md`.
- `docs/specs/auth.md`, `profiling.md`, `guest-mode.md`, `navigation.md` — Phase 6B requirements.
- `docs/specs/image-recognition.md` — Phase 6C; `docs/specs/algorithms.md` — postponed Phase 6D.
- `docs/specs/library.md` — Phase 6E Aklatan; `docs/api-contract.md` — endpoints the dashboard provides.
- `docs/specs/assistant.md`, `docs/setup/elevenlabs-assistant-setup.md`, `assistant/` — old
  ElevenLabs Percy (developer-only); `docs/specs/percy-local.md`, `data/percy/`, `scripts/percy/`
  — self-built Percy (Phase 9); `docs/percy-dataset-guide.md` — what sentences the team writes
  and how to retrain.
- `docs/specs/report-an-issue.md` — Phase 10.
- `docs/voice-offline-setup.md` — offline voice for testers; `tool/voice_models/README.md` —
  offline models: sizes, licenses, how they were built and uploaded.
- `docs/todo.md` — things set aside for later (Percy offline).
- `docs/testing/` — `system-test-checklist.md` (use every round), `first-tablet-test.md`, and
  per-feature checklists (`phase-6b/6c/6e`, `input-fix`, `voice-response`, `voice-speed-voice`,
  `server-accounts`, `library-web`, `percy-local`, `assistant`).
- `docs/database/` — table list, masterlist, ERDs, open questions, proposed SQL.
- `docs/features-summary.md`, `docs/implementation-summary.md`, `docs/system-masterlist.md`,
  `docs/thesis/` — thesis-facing summaries.
- `docs/prompts/revisions.md` — the 2026-10-13 revisions request.
- `docs/ui/` — mockups. **Mockup layout and wording win** over prompt text.
