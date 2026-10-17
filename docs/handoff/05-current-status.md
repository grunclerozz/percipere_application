# 05 — Current status (shared status board)

**Last updated: 2026-10-17 by Claude Code (merged `feat/voice-hold-interrupt` and
`docs/database-masterlist-v2` into `main`).** Every agent updates this file at the end of a
task (`docs/agent-rules.md` §1). Newest facts at the top of each section. History of each
task: `docs/handoff/worklog.md`.

## At a glance
- **App:** feature-complete for the thesis demo except the postponed phases (6D, 7, 8, 6E Part B).
  Almost everything built since 2026-10-07 **still waits for the user's tablet test**.
- **Last code change:** merge `d306cac` (2026-10-17) — brings `feat/percy-smarter`,
  `feat/voice-hold-interrupt` and the database masterlist v2 docs into `main`. Both merges were
  clean (no conflicts).
- **Last full test run:** 2026-10-15, `bash tool/test_each.sh`: 81 files, 981 tests, 0 failures.
  After the 2026-10-17 merge: `flutter analyze` clean; the Percy/voice/settings/accessibility
  test files (15 files) pass individually — see worklog entry below for the one file that
  needs the known isolated-run workaround.
- **Blocking the tablet test:** the 3 offline voice archives + `manifest.json` are not uploaded
  yet (dashboard `models/` folder and GitHub release `voice-models-v1`) — kept out of `main`
  as local, untracked, git-ignored files (`tool/voice_models/dist/`, 82 MB); dashboard branch
  `fix/webapp-api` merge state unverified.

## In progress / waiting
| Item | Who | State |
|---|---|---|
| App connection for the defense (`chore/app-connection`): runtime server address + Test connection + private-network cleartext rule + `docs/connection-guide-app.md` | Claude Code → user | built 2026-10-17; see worklog; tablet/MacBook test pending |
| Phase 6D algorithms (`feat/algorithms`, merged into `main` 2026-10-17): blur/dark/bright check + retake offer on camera captures, Otsu OCR fallback, WER calculator + hidden test screen, `docs/thesis/algorithms.md` | Claude Code → user | built, analyze clean, 34 changed-area test files pass; **release build not run** (no JDK reachable from the agent session). Tablet: tune `lib/config/image_quality_config.dart` from `[IMAGE QUALITY]` / `[OCR FALLBACK]` logs; try a blurry, a dark and a normal photo in Reader and Maglarawan; try the WER screen in a `PERCIPERE_DEV=true` build |
| Percy smarter (`feat/percy-smarter`, now merged into `main`) | team, then Claude Code | **provisionally retrained** 2026-10-16 (`model.json` new, evaluated on 58 team rows only; 5 new intents not evaluated). Waiting for team test phrases, then rerun `train.py` for the official evaluation + `docs/thesis/percy-evaluation.md`. Merged into `main` 2026-10-17, not pushed |
| Voice: hold to interrupt, false-error fix, latency, noise (`feat/voice-hold-interrupt`, now merged into `main`) | Claude Code | Phase B done 2026-10-16 (hold time config, TalkBack action, Percy turn drop, stale-error fix; tests for changed files pass). Waiting for user's tablet test; Phase C (latency, noise) after review. Merged into `main` 2026-10-17, not pushed |
| Upload offline voice models (`tool/voice_models/dist/*` + `manifest.json`) | user | not done (as of 2026-10-15); the local `tool/voice_models/` download folder is now git-ignored |
| Tablet test of everything since 2026-10-07 (checklists in `docs/testing/`, §15–18 of `system-test-checklist.md`) | user | waiting |
| First test with the real dashboard (`docs/testing/first-tablet-test.md`) | user | waiting |
| Dashboard: merge `fix/webapp-api` (REST) and `ui/rounded-no-shadow` | user | not merged as of 2026-10-13; now **unverified** |
| Dashboard privacy: drop personal columns (`v12_remove_personal_columns.sql`), rewrite git history holding old personal data | user decides | open |
| Percy: team adds sentences (`docs/percy-dataset-guide.md`), then retrain | team + agent | waiting for sentences |
| Shared Claude Code + Codex docs (`docs/agent-rules.md`, `AGENTS.md`, this folder) | Claude Code | done 2026-10-16, merged into `main` 2026-10-17, not pushed |
| Database masterlist v2 (`docs/database-masterlist-v2`, now merged into `main`) | Claude Code | docs only, merged 2026-10-17, not pushed |

## What's next (in order, unless the user says otherwise)
1. User uploads the models and runs the tablet tests; agents fix what the tests find.
2. Decide on "Percy offline" (dictation + Percy on the app's own Whisper model) after the
   offline-commands tablet test (`docs/todo.md`).
3. Phase 6E Part B (describing EPUB images) — **only after the user approves Part A**.
4. ~~Phase 6D~~ built 2026-10-17 (see table above); thesis write-up in `docs/thesis/algorithms.md`.
5. Phase 7 (SUS, usage logs, Library sync) and Phase 8 (evaluation, polish) — postponed.

## Branches (checked 2026-10-17 with `git branch -a`, `git log`)
| Branch | Tip | State |
|---|---|---|
| `main` (local) | `d306cac` | **merged** `feat/voice-hold-interrupt` (brings in `feat/percy-smarter`) then `docs/database-masterlist-v2` (brings in `docs/database-masterlist`) — both clean, no conflicts. 16 commits **not pushed** beyond `origin/main` (`54b6567`). |
| `feat/voice-hold-interrupt`, `feat/percy-smarter`, `docs/database-masterlist-v2`, `docs/database-masterlist` | — | fully contained in `main` now; safe to delete once the user confirms, kept for now |
| `origin/main` | `54b6567` | last pushed state of the app |
| `origin/batumbakla-patch-1` | `ba0207c` (2026-09-27) | teammate's README edits from before the baseline; **no common history with `main`**. Do not merge; ask the user. |
Pushing and merging are the user's call (`docs/agent-rules.md` §4).

## Phase status
| Phase | State |
|---|---|
| 1–6 (foundation, accessibility core, gestures, voice, TTS, OCR, Reader, Settings) | done, approved |
| 6B Registration, login, profiling, guest mode | done, approved |
| 6C Maglarawan (image description) | done, reviewed, approved |
| 6E Aklatan Part A | built 2026-10-06; books from the dashboard since 2026-10-11; awaiting tablet test |
| 6E Part B (EPUB images) | not started — wait for approval |
| 6D Core algorithms | built 2026-10-17, awaiting tablet tuning |
| 7 (reports, SUS, sync), 8 (evaluation, polish) | postponed |
| 9 Percy (self-built) | built 2026-10-10, retrained 2026-10-11; awaiting tablet test |
| 10 Report an Issue | built 2026-10-11; awaiting tablet test |

---

## Status history (moved from `CLAUDE.md` on 2026-10-16, newest last)
Kept word for word in meaning; only the ElevenLabs agent id was replaced by a pointer to
`lib/config/env.dart`.

- **Phases 1–6 and 6B (Registration, Login, Profiling): done and approved.** Since 6B:
  Reader text size (A−/A+, pinch, voice) and the voice listening-loop fix (logging, backoff,
  fallbacks).
- **Phase 6C — Maglarawan (image recognition): done, reviewed and approved.** Checklist
  `docs/testing/phase-6c-checklist.md`; spec `docs/specs/image-recognition.md`.
- **Phase 6E — Aklatan (Library): Part A built 2026-10-06, awaiting the user's tablet test;
  Part B (describing EPUB images) NOT started — wait for approval.** Part A: Library replaces
  Reading History, Home screen, details, favorites, collections, progress, admin books, PDF +
  EPUB. Part B only after the user has tested and approved Part A. Spec `docs/specs/library.md`.
- **Voice response time (2026-10-07):** partial-result commands, 1.2 s command pause (later
  1.3 s), 4 s dictation, earcon + pulse, listening while reading (barge-in), stale-result
  discard. Values in `lib/config/voice_config.dart`; checklist
  `docs/testing/voice-response-checklist.md`. Awaiting tablet test.
- **Input fix + "questions wait for the answer" (2026-10-07, second round):** single-file
  picking, distinct failure messages, plugin keep rules, build stamp in the log, version
  0.1.1+2; after a question the app waits `VoiceConfig.answerWait` (6 s) before giving
  instructions (`ScreenRegistration.followUp`). Checklist `docs/testing/input-fix-checklist.md`.
  Awaiting tablet test.
- **Percy via ElevenLabs Agents (2026-10-07)** — since Phase 9 only a hidden developer option
  (off by default); online only, the app's own voice stays. Spec `docs/specs/assistant.md`,
  setup `docs/setup/elevenlabs-assistant-setup.md` (run `assistant/setup_agent.py`; the user's
  agent and voice ids are built-in defaults in `lib/config/env.dart`), checklist
  `docs/testing/assistant-checklist.md`. Awaiting first live test. Also added then (was
  undocumented): controls tutorial, natural phrasing, document insights, familiarity.
- **Phase 9 — Percy (self-built), 2026-10-10.** Own intent classifier (scikit-learn →
  `assets/percy/model.json` → pure-Dart inference in `lib/core/percy/`), rule-based slots,
  frame-based dialogue manager, offline; replaces ElevenLabs as default. Spec
  `docs/specs/percy-local.md`; dataset `data/percy/intents.csv`; training `scripts/percy/`
  (README has the commands; Python and venv: `docs/handoff/09-environment.md`).
- **Voice latency + speed strip + reading voice (2026-10-10):** checklist
  `docs/testing/voice-speed-voice-checklist.md`; decision log 2026-10-10 (2). Awaiting tablet test.
- **Accounts on the web app (2026-10-10):** login, register with an emailed code, password
  reset by code and suspension checks go to the PHP dashboard (`api/v1/`) when built with
  `API_BASE_URL`; offline login with the copy on the tablet. Checklist
  `docs/testing/server-accounts-checklist.md`; decision log 2026-10-10 (3). Awaiting tablet test.
- **Phase 10 — Report an Issue (2026-10-11):** one question per page (Settings, Home,
  "mag-report" from any screen, Percy); saved locally (`issue_reports`, migration v6), sent to
  `POST api/v1/reports` with a `PRC-YYYYMMDD-XXXX` ticket, retried when offline; "Aking mga
  report" in Settings. Spec `docs/specs/report-an-issue.md`; checklist §15 of
  `docs/testing/system-test-checklist.md`; decision log 2026-10-11. Percy retrained the same day
  (27 intents, tuned by 5-fold cross-validation; decision log 2026-10-11 (2)). Awaiting tablet test.
- **Aklatan on the real dashboard (2026-10-11):** admin books from the REST API
  (`HttpAdminBookRepository`, `GET /api/v1/books`, SHA-256-checked downloads); the mock is gone
  from `lib/` (`FakeAdminBookRepository` is a test helper). Checklist
  `docs/testing/library-web-checklist.md`; decision log 2026-10-11 (3). Awaiting tablet test.
- **First tablet test prepared (2026-10-11):** guide `docs/testing/first-tablet-test.md`; plain
  http only to the `API_BASE_URL` host (+ `API_CLEARTEXT_HOSTS`), enforced by the Android
  network config and `CleartextGuard`; developer row "Server address" (`PERCIPERE_DEV=true`);
  "Aking mga report" shows the ticket status (migration v7). Decision log 2026-10-11 (5).
  App pushed to `main` (`54b6567`).
- **Dashboard (repo `percipere_web`, folder `percipere_dashboard`) — state 2026-10-13:** the
  app only works against dashboard branch `fix/webapp-api` (REST under `/api/v1`), not merged
  yet (the user merges; `main` there is the old version). On top: branch
  `ui/rounded-no-shadow` pushed (8px buttons, no shadows, filters removed, styled dropdowns,
  edit-book form fix). The user's XAMPP folder is that Git checkout; its database is at schema
  12 with no books yet. Open (user): merge the PRs, run `first-tablet-test.md`, decide on
  dropping personal columns and on rewriting git history with old personal data. Percy needs
  the team's sentences, then a retrain.
- **Revisions round (2026-10-13), `docs/prompts/revisions.md`, all 7 items built:** tutorial
  after setup (per account; guests once per device), starting with Percy's introduction; setup
  speed step Mabagal/Katamtaman/Mabilis with samples, prompts and Percy follow the speed;
  passwords visible while typing with an eye button; shared `PagePadding`. Second pass: Percy
  no longer ends on long-press / single tap / two-finger double tap / barge-in commands (the
  "conversation has ended" bug); silence → reminder after 9 s → goodbye after 9 s more;
  ElevenLabs only in a `PERCIPERE_DEV` build with its switch on (`elevenLabsActiveProvider`);
  developer "Percy analysis" panel (memory only). Checklist §16; decision log 2026-10-13 and
  2026-10-13 (2). Awaiting tablet test.
- **Voice regression + offline voice (2026-10-14, `881dd1a`):** silences timed by the app,
  commands 1.3 s / 10 s sessions / judged after 4 s of words, Percy 2.2 s; command-at-the-end
  and second-guess matching; listening plan offline → online → offline English → one message
  (`VoiceController._planNow`, `SpeechInfoBridge.kt`); TTS errors no longer wait, local voices
  preferred. New **Voice check** screen (Settings → "Pagsusuri ng boses"). Module audit fixes.
  Guide `docs/voice-offline-setup.md`; checklist §17. Awaiting tablet test.
- **Offline voice with the app's own engines (2026-10-15, `3bb1627`):** `881dd1a` still failed
  offline on the tablet and users must install nothing, so the app downloads its own
  sherpa-onnx models once at first launch (`/voice-setup` before Welcome, progress every 20 %):
  commands = Whisper tiny Filipino fine-tune + Silero VAD (keyword spotting rejected: 2 % on
  real Filipino speech), voices = MMS Tagalog + Piper English; 85.9 MB. Commands use it first
  (also online); dictation and Percy stay on Android's recognizer (`docs/todo.md`). Code
  `lib/core/offline_voice/`, `AudioBridge.kt`; models `tool/voice_models/` (the user uploads
  the 3 archives + `manifest.json`). Settings → Pagsusuri ng boses: model status, re-download,
  delete. Decision log 2026-10-15; checklist §18. Awaiting tablet test.
- **Codex handoff docs (2026-10-15, `55edf3c`)** and **shared Claude Code + Codex docs
  (2026-10-16)**: see `docs/handoff/worklog.md`.
- Phase 6D (Levenshtein/WER, Laplacian variance, Otsu): after 6E (`docs/specs/algorithms.md`).
- Phases 7 and 8: postponed.

## Recent commits by week (git history)
**Week of 28 Sep – 4 Oct:** `ee25f77`, `f126055` (1 Oct) baseline / clean project; `69796cd`
Phase 6B; `3104da2` review fixes; `0a95d72` (3 Oct) voice fixes, pinch zoom; `2924014`,
`287139e`, `735357c` (4 Oct) Phase 6C, quality-check rule, crash-proofing.
**Week of 5 – 11 Oct:** `9aa5771` thesis scope draft; `f24085c` "FIXED" / `dc29e01` "Latest atm"
(6E Part A, voice response, input fixes, ElevenLabs Percy — exact split unverified);
`a4d52a1`, `5db21b0`, `2c42e95`, `c753611` (10 Oct); `c8758d1`, `3e9c621`, `7deb1c3`, `1013c0d`,
`54b6567` (11 Oct).
**Week of 12 – 18 Oct:** `84a3fd7`, `c4b7975`, `d8f7eab`, `de4cac8` (13 Oct); `0e24bd8`,
`881dd1a` (14 Oct); `3bb1627`, `55edf3c` (15 Oct); shared docs (16 Oct).
