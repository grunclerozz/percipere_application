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
