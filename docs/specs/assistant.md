# Percy — the voice assistant (ElevenLabs Agents)

> **Since Phase 9 (2026-10-10) this is a hidden developer option, off by default.** The
> default Percy is self-built and offline: `percy-local.md`. The ElevenLabs path is used only
> when Settings → "Percy online (ElevenLabs, developer)" is on (shown in builds with
> `--dart-define=PERCIPERE_DEV=true`).

**Decided (user, 2026-10-07):** a Jarvis-like voice assistant inside the app, built only on
ElevenLabs; public agent while developing (private later), Free plan for development
(paid plan before user testing). The app's own offline voice commands stay as the base.

## Behaviour
- **Start:** two-finger swipe left (`NavIntent.assistant`, `gesture_map.dart`) or saying
  "percy", "hey percy", "kausapin si percy", "tawagin si percy", "katulong", "assistant"
  (also while a document is read). A screen can claim the gesture (the tutorial does).
- **Checks, in order:** agent id built in → internet → first-use spoken consent (per user,
  pref `assistant.consent`; "oo" / double-tap) → microphone. Each refusal has its own
  spoken message; nothing is sent to ElevenLabs before consent.
- **During the call:** the app's own listening is off; the app's prompts are shown as
  subtitles but not spoken (`Announcer` checks `assistantActiveProvider`); what Percy and
  the user say shows in the Speaking Zone. Any gesture, tap or command of the user's own
  ends the call and does nothing else (`CommandBus._userEndsAssistant`).
- **End:** Percy's `end_call` (after a hand-over or a goodbye), the user (gesture/tap), a
  20 s connection timeout, or an error. Then the app speaks "Tapos na ang usapan kay
  Percy." / the failure message, or runs the handed-over action, and listening resumes.
- **Language:** from the agent's dashboard settings by default. With
  `ELEVENLABS_USE_OVERRIDES=true` (agent must allow overrides) the app's speech language →
  agent language `tl` or `en`, first message from the ARB files, voice
  `ELEVENLABS_VOICE_ID`. Dynamic variables `user_name`, `app_language` are always sent.

## Tools (client tools, answered in Dart)
Defined once in `assistant/agent_config/tools.json` (sent to ElevenLabs by
`setup_agent.py`) and answered by `AssistantTools` through the command bus — Percy can do
exactly what the user can do. A test fails if the two lists differ.

| Tool | Does |
|---|---|
| `get_screen` | screen name, question, options, focus, Reader position |
| `go_to` | home, library, new_document, settings, back |
| `choose_option` | activates an option by name (fuzzy, Tagalog/English) |
| `list_library` | titles, type, progress (15 max) |
| `open_document` | fuzzy title → Reader (and read) — **hand-over** |
| `read_document` | read the open document — **hand-over** |
| `scan_document` / `upload_document` | camera / file picker — **hand-over** |
| `get_document_text` | open document's text, ≤ 6000 chars (questions, summaries) |
| `reading_settings` | faster / slower / bigger_text / smaller_text (saved settings) |
| `save_favorite` | favorite at the current sentence (Reader) |
| `describe_controls` | the screen's help, mode hint, how to call Percy |

**Hand-over:** the action needs the app's own voice (reading, camera guidance) or the
whole screen (picker), so it runs after the call ends; Percy is told to say one sentence
and call `end_call`; the app ends the call itself after 8 s if Percy doesn't.

## Parts
- Android: `AssistantBridge.kt` (ElevenLabs Android SDK 0.12.2, `io.elevenlabs:elevenlabs-android`;
  needs JitPack for LiveKit's `audioswitch`, scoped in `android/build.gradle.kts`;
  keep rules in `proguard-rules.pro`). Channels `ph.bataan.percipere/assistant` and
  `…/assistant_events`.
- Dart: `lib/core/assistant/` — `assistant_platform.dart` (channel + events),
  `assistant_config.dart` (dart-defines, token fetch), `assistant_controller.dart`
  (state, consent, events, hand-over), `assistant_tools.dart`, `reader_snapshot.dart`
  (published by the Reader).
- Python (on the PC / server only): `assistant/setup_agent.py` (configures the agent via the
  ElevenLabs REST API), `assistant/server/token_server.py` (private agents),
  tests in `assistant/tests`.
- Build-time settings (`lib/config/env.dart`): `ELEVENLABS_AGENT_ID`,
  `ELEVENLABS_VOICE_ID` (default `EST9Ui6982FZPSi7gCHi`), `ELEVENLABS_TOKEN_URL`,
  `ELEVENLABS_APP_KEY`.

## Privacy
Consent names what is sent (speech, and document text when asked about it) and to whom.
Document text goes only through `get_document_text`, i.e. when the user asks about the
document. Percy's instructions avoid repeating ID/account numbers and give no medical,
legal or financial advice. Consent can't yet be withdrawn from Settings (known gap).
