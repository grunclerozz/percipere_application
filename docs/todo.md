# To do (later)

- **Percy offline – later.** Percy's free conversation and dictation (names, email,
  passwords, collection names) still use Android's recognizer, so offline they need Google's
  offline language pack. The app's own Filipino Whisper model (`percipere-asr-fil-en`) could
  transcribe them too (free text through `OfflineCommandListener` without the 4 s cap);
  decide after the 2026-10-15 offline-commands tablet test.
- Offline commands: if the tablet test shows too many misses, try the Whisper **base**
  Filipino fine-tune (`tool/voice_models/README.md`, server-side swap) and tune the
  matcher's phrases with the words logged as `[OFFLINE VOICE] heard "…"`.
- Dashboard: a real `GET /api/v1/models` route (today the static `models/manifest.json` is
  enough; `docs/api-contract.md`).
