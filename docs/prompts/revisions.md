Read CLAUDE.md first. Revisions from our latest test on the tablet. For each item: find the
cause first (tell me what broke and when, using git log/blame if it's a regression), then fix.

1. TUTORIAL IS GONE (regression)
   The first-run tutorial no longer appears. Find which commit removed or bypassed it (route
   removed, first-run flag set too early, onboarding order changed, merge conflict, etc.).
   Restore it so new users see it after registration/profiling (and guests on first launch).
   It must be replayable: Settings → "Tutorial", Help screen, and voice ("tutorial",
   "turuan mo ako", "paano gamitin"). Spoken, step by step, skippable ("laktawan"), and
   each step can be repeated ("ulitin").

2. SPEECH SPEED MISSING IN REGISTRATION
   Add a "Bilis ng pagsasalita" (speech speed) step to the registration/profiling flow:
   Mabagal / Katamtaman (default) / Mabilis. Play a short sample sentence at each speed as the
   user moves between options, so they can hear the difference before choosing. Save it to the
   profile and apply it to all TTS immediately (reader, prompts, Percy). Also make sure it can
   be changed later in Settings and with the existing "faster/slower" commands.

3. PASSWORD VISIBLE WHILE TYPING (required by our adviser/panel – implement, don't skip)
   On register, login, and password reset: the password is VISIBLE by default while typing.
   Add an eye button to hide it ("Itago ang password" / "Ipakita ang password"), large touch
   target, TalkBack label, large high-contrast text. The visible/hidden choice resets to
   visible each time the screen opens.
   When the password field is focused, say once (TTS): "Nakikita ang password habang
   nagta-type. Pindutin ang mata para itago."
   Rules that stay: the app's own TTS and Percy never read the password aloud, and passwords
   are never logged or sent anywhere except the login/register API over the existing
   connection. Mention in docs that TalkBack itself may speak typed characters, so users in
   public can hide the password or use earphones.

4. PERCY ALWAYS SAYS "THE CONVERSATION HAS ENDED"
   That message is the ElevenLabs agent's end message, so check first whether any ElevenLabs
   code path is still active (it must be off by default behind the hidden dev setting). Then:
   - Percy must use our self-built offline Percy (intent classifier + dialogue manager) only.
   - Find why sessions end immediately (timeout, silence detection, STT error treated as end,
     restart loop). Percy should stay listening for a reasonable pause (e.g. 8–10 seconds of
     silence), reprompt once ("Nandito pa ako. Ano ang maitutulong ko?"), and only then end
     with a short Filipino goodbye. Never show or speak "The conversation has ended".
   - Add tests for: normal multi-turn conversation, silence → reprompt → end, STT error →
     retry, user says goodbye.

5. INTRODUCE PERCY AT THE START
   At first launch (as part of onboarding, before/at the start of the tutorial), Percy
   introduces itself as the app's voice assistant, in Filipino, short:
   who Percy is, how to call Percy (the gesture and/or button and voice), 2–3 example commands
   ("basahin mo", "buksan ang Aklatan", "bumalik"), and that it works offline. Also make
   "Sino ka?" / "Ano ang kaya mo?" answer with this intro anytime. Add these phrases to
   data/percy/intents.csv under the right intents (help/greeting) if missing.

6. PADDING / NOT CENTERED ON SOME SCREENS
   Some screens are off-center or have uneven padding. Audit every screen: use SafeArea,
   consistent horizontal padding from one shared spacing constant, center content
   horizontally, and on wide screens (tablet) constrain content to a max width and center it.
   No overflow when text size is largest. Add widget tests that pump key screens at phone and
   tablet sizes (e.g. 360x800 and 800x1280) at normal and largest text size and check for no
   overflow. List any screen you changed.

7. PERCY – VOICE ANALYSIS
   (a) Report which speech engines Percy uses right now: STT (speech_to_text, which locale)
       and TTS (flutter_tts, which voice/engine, or anything else). Percy must speak with the
       same on-device voice and speed as the rest of the app.
   (b) Add a "Percy analysis" panel (hidden developer setting, off by default) that shows for
       each utterance: what was heard (transcript), detected language, predicted intent,
       confidence score, top 3 intents, and the action taken. This is for testing and for our
       Intelligent Systems demonstration. Don't store audio.

END OF PHASE
Update docs/testing/system-test-checklist.md with checks for all 7 items. Run the quality
check (analyze + tests), don't run the app on my device, update CLAUDE.md status, commit.