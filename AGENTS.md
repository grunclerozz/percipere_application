# AGENTS.md — Percipere (Flutter app), guide for OpenAI Codex

> **Rules live in `docs/agent-rules.md`. Update that file, not this one.**
> This repo is shared with Claude Code (`CLAUDE.md`); both agents follow the same rules.

## Read first, every session
1. `docs/agent-rules.md` — workflow, quality check, git, privacy, UI and reporting rules.
2. `docs/handoff/05-current-status.md` — the shared status board (what's done, in progress,
   branches, what's next).
3. The latest entries of `docs/handoff/worklog.md`.
Then the handoff file for the area you touch (`docs/handoff/01`–`09`).

## Project
**Percipere** is an **Android-only** Flutter app that reads printed and digital text aloud for
visually impaired users in Bataan, Philippines. It is used **without seeing the screen**, by
**gestures** (Gesture Pad), **voice** and touch. **Filipino default**, English second.
**Offline-first**; the internet is only for the PHP/MySQL web dashboard (separate repo:
accounts, admin books, reports — see `docs/handoff/04-api-and-dashboard.md`) and the one-time
offline-voice model download. Undergraduate thesis, non-commercial.

Stack: Flutter + Riverpod 3 (no codegen) · go_router · sqflite · ML Kit · speech_to_text +
sherpa-onnx · flutter_tts + sherpa-onnx voices · self-built Percy assistant (`lib/core/percy/`).
Details: `docs/handoff/01-architecture.md`.

## The rules that matter most (full text in `docs/agent-rules.md`)
- Work in phases; stop after each for review. Ask before major architectural changes.
- Never run the app on the user's tablet (emulator `Percipere_Light` is fine).
- End-of-phase quality check: `flutter analyze`, `bash tool/test_each.sh`, release build.
- Never push without the user's OK; never push to `main`; work on branches.
- No secrets in code or docs; never call Gemini/AI APIs from the app; passwords never logged
  or spoken by Percy; own documents stay on the device; RA 10173.

## Codex specifics: running commands on Windows
- Host is Windows. Project: `D:\Development\Flutter Projects\percipere_app` — **quote the path**.
- Default shell may be PowerShell 5.1: chain with `;` (no `&&`). Use Git Bash for scripts:
  `bash tool/test_each.sh` (full suite, each file alone, retries random `flutter_tester` crashes).
- Common commands:
  ```bash
  flutter pub get
  flutter analyze
  bash tool/test_each.sh
  flutter test test/core/voice/
  flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard
  ```
- The full suite takes ~1–1.5 h and a release build several minutes: allow long timeouts.
  Don't run tests and a build at the same time.
- If Gradle says `Unable to establish loopback connection`, set
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\tmp\jdk`.
- If your sandbox blocks network or the Android SDK, say so in the report instead of skipping
  checks silently. More tool paths and config names: `docs/handoff/09-environment.md`.
- Commit messages follow `docs/agent-rules.md` §4; add a worklog entry with `Agent: Codex`.
