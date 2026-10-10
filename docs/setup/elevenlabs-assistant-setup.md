# Setting up Percy, the voice assistant (ElevenLabs)

Percy is an ElevenLabs voice agent built into the app. It is **online only**; without it
(no internet, no credits, not set up) the app's own voice commands and gestures work as
before. You need: an ElevenLabs account, the agent's **Agent ID**, and (once) your
**API key** on your PC.

> Never put the API key in the app, in the project files, or in a chat. It only goes in
> the terminal on your PC (step 2) and, for a private agent, on the token server.

## 1. Create the agent (dashboard)
1. elevenlabs.io → **Agents** → **Create agent** → **Blank** (or any template).
2. Copy the **Agent ID** (`agent_…`) from the agent's settings or the page address.
You don't have to fill in the instructions, tools, language or voice by hand: step 2 does it.

## 2. Configure it from your PC (once, and again after app updates that change Percy)
In PowerShell, in the project folder:

```powershell
pip install -r assistant/requirements.txt
$env:ELEVENLABS_API_KEY = "paste your key here"
python assistant/setup_agent.py
```
(Your agent `agent_1601m4b0j87se7x8tmtehq4znmas` is the default; add
`--agent-id agent_…` for another one.)

This creates the app's 12 tools, sets Percy's instructions (`assistant/agent_config/prompt.md`,
Tagalog + English), Filipino as the main language with English as an extra language, the
voice `EST9Ui6982FZPSi7gCHi`, a 5-minute limit per conversation and 30 conversations a
day, lets the app choose language/first message/voice per call, and keeps the agent
**public**. Options: `--voice-id`, `--max-minutes`, `--daily-limit`, `--private`,
`--dry-run` (shows what it would send). If it prints "language 'tl' was refused", it
retries with `fil` by itself.

Then, in the dashboard, set a **usage limit** for your account (Free plan: about 15
agent minutes a month).

## 3. Build the app
Your Agent ID and voice are built in by default, so a normal build is enough:
```powershell
flutter build apk --release
# or for testing:
flutter run
```
For a different agent: `--dart-define=ELEVENLABS_AGENT_ID=agent_…`.

**Greeting, language and voice come from the dashboard.** By default the app doesn't
change them per call (an agent that doesn't allow overrides ends the call at once with
"Override for field 'first_message' is not allowed by config"). To let the app choose the
Tagalog/English greeting, language and voice `ELEVENLABS_VOICE_ID` itself: turn on
**Security → Overrides → First message, Language, Voice** in the dashboard (the setup
script does this) and build with `--dart-define=ELEVENLABS_USE_OVERRIDES=true`.
For phones, a smaller APK per processor type: add `--split-per-abi` and install
`app-arm64-v8a-release.apk` (most phones) — the full APK is ~185 MB because of the
voice-call (WebRTC) libraries.

With `--dart-define=ELEVENLABS_AGENT_ID=` (empty) the app works normally and Percy says it isn't set up.

## 4. Use it
- **Call Percy:** two-finger swipe left, or say "Percy" / "katulong" / "assistant".
- The first time, Percy's privacy question: double-tap or say "oo" to agree.
- **End:** say "paalam" / "tapos na", or make any gesture or tap.
- Ask: "nasaan ako?", "ano ang mga dokumento ko?", "buksan ang bill ng Meralco at
  basahin", "magkano ang babayaran?", "ibuod mo", "bilisan ang boses", "paano gamitin ang
  app?".

## Optional: private agent (before real users)
Only your app can then start conversations (the Agent ID alone isn't enough).
```powershell
python assistant/setup_agent.py --agent-id agent_XXXXXXXX --private
$env:ELEVENLABS_AGENT_ID = "agent_XXXXXXXX"
$env:PERCIPERE_APP_KEY = "any long random text"
uvicorn assistant.server.token_server:app --host 0.0.0.0 --port 8787
```
Build with
`--dart-define=ELEVENLABS_AGENT_ID=agent_XXXXXXXX --dart-define=ELEVENLABS_TOKEN_URL=http://<PC IP>:8787/assistant/token --dart-define=ELEVENLABS_APP_KEY=<same text>`
(phone on the same Wi-Fi). For real use, host it behind HTTPS (e.g. with the web admin
app).

## Logs
`adb logcat -s flutter | findstr ASSISTANT` shows each step (`started`, `tool …`,
`ended by agent/user/error`). Native SDK messages: `adb logcat -s PercipereAssistant`.
