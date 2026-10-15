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
