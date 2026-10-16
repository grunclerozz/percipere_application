# A2 – Voice reliability fix (Opus 5.5, new chat) – MOST IMPORTANT

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/05-current-status.md, the latest worklog
entries, docs/handoff/03-voice-and-percy.md and 01-architecture.md.
Create branch fix/voice-reliability from main.
SCOPE rule: touch only files this task needs; ask before changing dependencies, build
settings, or other features. Don't run the app on my tablet. Run flutter analyze and only
tests for changed code; don't run the full suite or emulator test. I'll test on the tablet.

The hold-to-interrupt work is finished and merged: treat it as the baseline, don't redo it.
Code: lib/core/voice/, lib/core/offline_voice/, lib/config/voice_config.dart,
lib/core/gestures/, lib/core/accessibility/command_bus.dart, lib/core/percy/percy_controller.dart.

PROBLEMS SEEN ON THE TABLET (fix the root cause, not symptoms)
1. Commands sometimes must be said TWICE before they register. The first attempt is lost.
2. The hold gesture sometimes must be done TWICE to "lock in" listening.
3. Sometimes it says the voice is "not available right now" (voiceRepeatedError in
   lib/l10n/app_fil.arb) and then still shows/acts on what I said.
Likely causes to check (unverified): the recognizer not ready yet when listening starts
(first words cut off, engine still loading or TTS/audio focus not released); listen started
before the previous session fully stopped; a race between stop/cancel and the final result;
a transient error/timeout counted as failure while a late result is still arriving; the
offline/online hybrid cancelling a recognizer that still delivers; double-tap/hold events
toggling listening on then off.

REQUIRED
- A late valid result must never be thrown away; a transient error must not count as
  "repeated"; keep the safeguard for truly dead recognizers.
- Listening must be ready before the "listening" tone plays; one hold = listening starts,
  every time; no double toggles.
- Low-risk noise improvement only: Android audio source / noise suppression / AGC flags if
  available, and in high noise confirm low-confidence commands ("Ito ba ang ibig mong
  sabihin…?") instead of failing. No new heavy models, no engine switch.
- Don't change Percy's confidence thresholds. No audio leaves the phone.
- Strings in ARB files (Filipino first), polite "po" style; voice + gesture + tap still work.

DO: Phase A (find the root cause with a log trace or a test that reproduces 1–3; measure
where the delay goes) and then go straight into Phase B (fix + tests). STOP only if you
need a decision from me or a fix is risky.

FINISH: create a quick repeatable tablet test: 20 commands in a quiet room and 20 in a
noisy room, logged to a CSV (recognized text, matched command, attempts needed, response
time) via the hidden developer settings. Run analyze + tests for changed code; if all pass,
merge fix/voice-reliability into main. Update docs/handoff/03, 05, 06, 07 and the worklog;
commit (don't push). Report: root cause(s), what changed, Passed, Known issues, and exact
manual tablet tests (quiet, noisy, hold while Percy talks, offline/airplane mode).
