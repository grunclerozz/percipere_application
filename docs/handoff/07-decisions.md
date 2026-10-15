# 07 — Key decisions and why

Short summary. The full dated log (newest first) is `docs/specs/decisions.md`; add new
decisions there.

| Date | Decision | Why | Where |
|---|---|---|---|
| 2026-09-30 | Android-only Flutter app, offline-first, Filipino default | Users are blind/low-vision people in Bataan; connectivity is unreliable | `CLAUDE.md` |
| 2026-09-30 | One action registry: gestures, voice and taps run the same `A11yAction`s through the CommandBus | Consistent behaviour, every action reachable three ways | `lib/core/accessibility/` |
| 2026-10-01 | Fixed layout, no page scrolling; text size only enlarges the reading text | Review: overlaps and scrolling confuse users who can't see | decisions 2026-10-01, 2026-10-03 |
| 2026-10-04 | Maglarawan offline labels first; online detail only with spoken consent, via the server (Gemini on the dashboard, no API key in the app) | Privacy, offline-first; the app never calls AI APIs directly | `docs/specs/image-recognition.md` |
| 2026-10-06 | Aklatan (Library) replaces Reading History; Phase 6D postponed | User priority | decisions 2026-10-06 |
| 2026-10-07 | Release-APK input bugs fixed with R8 keep rules; always test native plugins in a release build | Inputs worked in debug, failed in release | decisions 2026-10-07 |
| 2026-10-10 | **Self-built Percy** (scikit-learn intent classifier exported to JSON, pure Dart, offline) replaces ElevenLabs; ElevenLabs kept only as a hidden developer option | **Intelligent Systems class requirement**: own model, no external AI API | `docs/specs/percy-local.md` |
| 2026-10-10 | Accounts on the dashboard (email code, reset, suspension), with offline login for accounts already used on the tablet | Thesis needs server accounts; offline-first must still work | decisions 2026-10-10 (3) |
| 2026-10-11 | **REST API** under `/api/v1` (old `.php` URLs deprecated) for books, accounts, reports | Clean, testable contract shared with the dashboard | `docs/api-contract.md` |
| 2026-10-11 | **Admin books maintained in the dashboard**; app downloads with size + SHA-256 check; public domain or licensed only | Admins manage content; integrity; copyright | `docs/specs/library.md` |
| 2026-10-11 | Reports send `type`/`module`/`severity` as **`{code, label}`**; reporter name not sent | Codes for logic, labels for the dashboard display; less personal data | decisions 2026-10-11 (4) |
| 2026-10-11 | Plain HTTP only to the configured server host (Android config + Dart `CleartextGuard`) | Testing on a LAN PC without opening cleartext to every host | decisions 2026-10-11 (5) |
| 2026-10-11 | "Natanggap" instead of "Bukas" for an open ticket | "Bukas" is ambiguous when read aloud | decisions 2026-10-11 (5) |
| 2026-10-13 | **Password visible by default** with an eye (hide) toggle; never spoken by the app or Percy | Required by the adviser/panel | decisions 2026-10-13 |
| 2026-10-13 | Tutorial after setup, per account (guests per device), starting with Percy's intro | Tutorial was missed by later users | decisions 2026-10-13 |
| 2026-10-13 | Percy stays in the conversation through long-press/tap/stop-speech; silence reminder then goodbye | Fixed the "conversation has ended" bug | decisions 2026-10-13 (2) |
| 2026-10-14 | Silences timed by the app, never handed to Android; listening plan offline → online → offline English | Android held results back by the 4 s wait; voice only worked online | decisions 2026-10-14 |
| 2026-10-15 | App downloads its **own offline engines** (sherpa-onnx: Whisper tiny Filipino + Silero VAD; MMS Tagalog + Piper English voices), first for commands | Users must not install Google packs; keyword spotting failed on real Filipino speech (2%) | decisions 2026-10-15, `tool/voice_models/README.md` |
| 2026-10-15 | **Percy offline postponed** (dictation and Percy stay on Android's recognizer) | Scope kept small for this round | `docs/todo.md` |

Standing rules that came from decisions: privacy under RA 10173 (minimum data, own documents
stay on the device), passwords never logged or spoken, end-of-phase quality check
(`AGENTS.md`).
