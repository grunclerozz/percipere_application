# Percy (voice assistant) — phone checklist

Setup first: `docs/setup/elevenlabs-assistant-setup.md` (run `setup_agent.py`, then a normal build — your agent id is built in). Logs: `adb logcat -s flutter | findstr ASSISTANT`.
Test once with `flutter run` and once with the release APK. Watch your ElevenLabs minutes.

## Without set-up / offline
- [ ] App built with `--dart-define=ELEVENLABS_AGENT_ID=` (empty): two-finger swipe left →
      "Hindi pa naka-set up si Percy…". Everything else works.
- [ ] With the agent id, Wi-Fi and data off: "Kailangan ng internet para kay Percy…".

## First call
- [ ] Two-finger swipe left on Home: the privacy question. Say "hindi" → nothing happens,
      "Sige, hindi muna gagamitin si Percy…".
- [ ] Again, say "oo": "Tinatawag si Percy." then Percy greets you in Tagalog (your voice
      choice). The second time, no question.
- [ ] Saying "Percy" (voice mode) also calls it.

## Talking
- [ ] "Nasaan ako?" → Percy names the screen and options correctly.
- [ ] "Ano ang mga dokumento ko?" → lists your Aklatan.
- [ ] "Pumunta sa Aklatan" → the Library opens (the app stays silent; Percy talks).
- [ ] "Buksan ang <title> at basahin" → Percy says one sentence, the call ends, the Reader
      opens and reads with the app's voice.
- [ ] With a document open: "Ano ang laman nito?", "Magkano?", "Ibuod mo" → answers only
      from the document.
- [ ] "Bilisan ang boses" / "Palakihin ang text" → the setting changes (check Settings).
- [ ] "Kunan ng litrato" → call ends, camera guidance starts.
- [ ] "Paano gamitin ang app?" → explains gestures.
- [ ] English: switch the app to English → Percy greets and answers in English; Taglish
      works either way.

## Ending
- [ ] "Paalam" → Percy says goodbye, the call ends, "Tapos na ang usapan kay Percy.", the
      app listens again (voice mode).
- [ ] Any gesture during the call ends it at once and does nothing else.
- [ ] During reading, say "Percy": reading stops, Percy answers.
- [ ] Airplane mode during a call → "Hindi makakonekta kay Percy…", the app works again.

## Quality (tell me)
- How natural is the Tagalog voice? Is the delay before Percy answers acceptable?
- Did Percy ever do something you didn't ask, or make up document content?
