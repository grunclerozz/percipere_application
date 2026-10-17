# Percipere — guide for Claude Code

> **Rules live in `docs/agent-rules.md`. Update that file, not this one.**
> This repo is shared with OpenAI Codex (`AGENTS.md`); both agents follow the same rules.

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
accounts, admin books, reports) and the one-time offline-voice model download. Undergraduate
thesis, non-commercial.

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

## Claude Code specifics
- Windows host. The project path has a space: quote it. The Bash tool runs Git Bash;
  `tool/test_each.sh` needs it. The full suite takes ~1–1.5 h — run it in the background.
- Use the desktop app's task list and wrap-up as usual; the worklog entry and
  `05-current-status.md` update are still required (they are what Codex reads).
- Co-author line in commits as the harness instructs.
