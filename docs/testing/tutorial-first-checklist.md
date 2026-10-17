# Tablet checklist — controls tutorial first (`feat/tutorial-first`)

What changed: on the **first launch** (no saved session, tutorial never finished on this device)
the controls tutorial opens **before Welcome** (Login / Register / Subukan muna). It needs no
account. It is not shown after registering, logging in or profiling. Replay: Settings → "Paano
gamitin ang app", or say "paano gamitin".

Skip rule (first launch only): until Percy's introduction (step one) has been spoken, the
two-finger swipe right, "laktawan" / "skip", the Laktawan button **and the double-tap that
moves on** are ignored (the button is hidden). If the voice fails or is cut off, they work
after **60 seconds** (logged as `[TUTORIAL] skip allowed: safety timeout…`). In a replay
everything works from the start.

Build: debug or release. Logs: `adb logcat -s flutter`, look for `[TUTORIAL]`, `[STARTUP]`.
"Clear data" = Settings → Apps → Percipere → Storage → Clear data (this also resets the voice
models, so the download screen comes back).

| # | Test | Expected | Result |
|---|---|---|---|
| 1 | **Fresh install** (or clear data), with the voice models already installed (or internet on for the download) | Download screen first only if the models are missing; then the loading screen ("Pakihintay po, inihahanda ang Percipere…" → "Handa na po"); then the tutorial: "Pag-aaral ng mga kontrol", then Percy introduces itself. Welcome does **not** come first | |
| 2 | During Percy's introduction (step one) swipe two fingers right | Nothing happens; no error spoken; the introduction keeps going | |
| 3 | During step one say "laktawan", then "skip" | Ignored, no reply, nothing spoken about skipping | |
| 4 | During step one, double-tap | Ignored: stays on step one, no "Tuturuan kita…" | |
| 5 | During step one: is a "Laktawan" button on the screen? | **No** (hidden) | |
| 6 | Let step one finish, then look at the screen | "Laktawan" button appears (button only; nothing is announced) | |
| 7 | Double-tap after step one | Goes on to step two ("Tuturuan kita…"); step two says how to skip | |
| 8 | Skip after step one (two-finger swipe right on step two) | "Nilaktawan ang pag-aaral…", then **Welcome** (Login / Register / Subukan muna) | |
| 9 | Close the app (swipe from Recents) and open it again | Loading screen, then **Welcome**; the tutorial is **not** shown again | |
| 10 | Clear data and repeat 1; this time go through all steps (swipe right/left, double-tap, tap, two-finger swipe, three-finger tap, hold, say "tulong") | Each practice step works as before; the last step ends in Welcome | |
| 11 | Clear data, repeat 1; this time skip by voice ("laktawan") after step one | Same as 8 | |
| 12 | Register a new account from Welcome, finish the setup (profiling) | Setup ends on **Home**, the tutorial is **not** shown again | |
| 13 | Log in with an existing account on a tablet that never saw the tutorial | Goes to Home (or the setup), no tutorial | |
| 14 | **Replay**: Settings → "Paano gamitin ang app" (also try saying "paano gamitin" on Home) | Opens the tutorial; the Laktawan button is there from the start; skip and double-tap work at once; skipping or finishing returns to Settings (or the screen you were on) | |
| 15 | **Safety timeout**: a build or voice where speech fails (e.g. TTS engine stopped), first launch | Skip stays off for about 60 s, then works; log line `[TUTORIAL] skip allowed: safety timeout after 60s` | |
| 16 | **No voice models yet, internet ON** (clear data) | Download screen, then loading, then the tutorial. Voice in the tutorial ("tulong", "laktawan") works through Android's recognizer; gestures work. **Unverified: write down what happened** | |
| 17 | **No voice models, internet OFF** (airplane mode, clear data) | Download screen says there is no internet and moves on; then the tutorial. Gestures and taps work. Voice may not work (no models, no recognizer without internet). **Unverified: write down what happened**, and whether the user could still finish or skip by gesture | |
| 18 | TalkBack on, first launch | The tutorial is announced; the skip rule behaves the same (TalkBack speech is timed roughly) | |
| 19 | Language: Filipino is spoken by default; switch the device language to English and clear data | Tutorial texts in the chosen language | |

Send back: for any failure, the `[TUTORIAL]`, `[STARTUP]` and `[VOICE STATE]` lines around it,
and the answers to 16 and 17.
