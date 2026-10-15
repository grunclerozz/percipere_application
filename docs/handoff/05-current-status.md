# 05 — Current status (as of 2026-10-15)

Sources: `git log`, `CLAUDE.md` "Current status", `docs/specs/decisions.md`.

## Recent work by week (git history)
**Before the repo (decision log, 30 Sep):** Phases 1–6 built (foundation, accessibility core,
gestures, voice commands, TTS, OCR, Reader, Settings).

**Week of 28 Sep – 4 Oct**
- `ee25f77`, `f126055` (1 Oct): baseline of Phases 1–6, replaced by a clean Flutter project.
- `69796cd` (1 Oct): Phase 6B — registration, login, profiling, guest mode, back navigation.
- `3104da2` (1 Oct): review fixes (fixed layout; text size only enlarges reading text).
- `0a95d72` (3 Oct): voice command fixes, pinch zoom.
- `2924014`, `287139e`, `735357c` (4 Oct): Phase 6C Maglarawan; end-of-phase quality check rule; crash-proofing.

**Week of 5 – 11 Oct**
- `9aa5771` (6 Oct): thesis objectives/scope draft. Phase 6E Part A (Aklatan) built 6 Oct
  (landed in later commits `f24085c` "FIXED" / `dc29e01` "Latest atm"; exact commit unverified).
- `f24085c` (7 Oct): voice response time, release-APK input fixes, questions wait for answers,
  ElevenLabs Percy (per decision log 2026-10-07).
- `a4d52a1`, `5db21b0`, `2c42e95`, `c753611` (10 Oct): latest copy; Phase 9 self-built Percy;
  voice latency + speed strip + reading voice; accounts on the dashboard.
- `c8758d1`, `3e9c621`, `7deb1c3`, `1013c0d`, `54b6567` (11 Oct): Phase 10 Report an Issue; Percy
  retrain; Aklatan books from the dashboard; REST URLs; first tablet test prep.

**Week of 12 – 18 Oct**
- `84a3fd7` (13 Oct): CLAUDE.md status.
- `c4b7975`, `d8f7eab` (13 Oct): revisions round (tutorial after setup + Percy intro, named
  speech speeds, visible password, page padding; Percy stays in the conversation; analysis panel).
- `de4cac8` (13 Oct): features summary for the thesis.
- `0e24bd8` (14 Oct): database masterlist, ERDs, table list (`docs/database/`).
- `881dd1a` (14 Oct): voice regression fix (timings, listening plan, Voice check screen).
- `3bb1627` (15 Oct): offline voice with the app's own engines (sherpa-onnx), first-launch
  download, Settings model controls.

## In progress / waiting
- **Offline voice models:** built and tested on PC + emulator. Waiting for the user to upload
  `tool/voice_models/dist/*` (+ `manifest.json`) to the dashboard `models/` folder and the GitHub
  release `voice-models-v1`, then the tablet test (`docs/testing/system-test-checklist.md` §18).
- **Tablet tests pending** for nearly everything since 7 Oct: voice response/latency, input fix,
  accounts on the dashboard, reports, Aklatan from the dashboard, revisions round, voice
  regression fix, offline voice (checklists in `docs/testing/`).
- **Dashboard side (state 2026-10-13, unverified now):** branch `fix/webapp-api` (REST) not
  merged; `ui/rounded-no-shadow` pushed on top; dashboard DB at schema 12 with no books.
  Open: dropping personal columns (`v12_remove_personal_columns.sql`), rewriting git history
  that still holds old personal data.
- **Percy data:** the team should add sentences (`docs/percy-dataset-guide.md`) and retrain.
- Phase 6E Part B (EPUB images): not started, needs approval. Phase 6D, 7, 8: postponed.

## Branches (local repo, 2026-10-15)
| Branch | Tip | State |
|---|---|---|
| `docs/database-masterlist` (current) | `3bb1627` | 2 commits **not pushed** (`881dd1a`, `3bb1627`) beyond `origin/docs/database-masterlist` (`0e24bd8`). Contains all of `main`. |
| `main` | `de4cac8` | 4 commits **not pushed** beyond `origin/main` (`54b6567`). Does not yet contain `0e24bd8`, `881dd1a`, `3bb1627`. |
| `origin/main` | `54b6567` | last pushed state of the app |
Nothing is merged into `main` from `docs/database-masterlist` yet. Pushing/merging is the user's call.
