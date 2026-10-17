# Tablet checklist — loading screen, busy voice, push-to-talk (`fix/voice-startup-ptt`)

Build: a developer build helps (`--dart-define=PERCIPERE_DEV=true`): turn on Settings →
"Estado ng boses (developer)" to see the voice state (naglo-load / handa / nagsasalita /
nakikinig / nagpoproseso) and the last cold start's load time at the bottom-left of every
screen. Logs: `adb logcat -s flutter`; look for `[STARTUP]`, `[VOICE STATE]`, `[VOICE …]`.
"Cold start" = swipe the app away from Recents (or `adb shell am force-stop ph.bataan.percipere.app`)
and open it again.

Push-to-talk, everywhere: **press and hold the gesture area while you speak, let go when you
are done** ("Pindutin nang matagal habang nagsasalita, bitawan kapag tapos na."). A tone plays
when the microphone is live. A touch shorter than about 0.3 s never listens.

| # | Test | Expected | Result |
|---|---|---|---|
| 1 | **Cold start on the login screen** (an account with "stay logged in" off, or log out first) | Loading screen: "Pakihintay po, inihahanda ang Percipere." Progress bar and 5 lines (Mga setting at datos, Boses ng app, Pakikinig sa boses, Si Percy, Pagbasa ng larawan) turn "handa na". Then "Handa na po." + tone, then the login screen speaks. **Write down the load time** (overlay "Pagbukas: … s", or `[STARTUP] ready after …ms … since launch`). Nothing listens and no other prompt plays while loading. | |
| 2 | Same, then at once hold and say "register" (or a field value), let go | Listens at the first try; no "Hindi gumagana…", no "Hihinto muna ako"; acts after you let go | |
| 3 | **Register**: hold and say your first name, let go; repeat for each field | Each field heard at the first try; the field fills right after you let go (≈0.4 s) | |
| 4 | **Guest** ("Subukan muna") from Welcome right after a cold start | Same as 2; commands work at the first try | |
| 5 | **Home** (logged in, cold start) | Loading screen, then Home; hold "aklatan" → Library at the first try | |
| 6 | **Upload, then hold immediately** (Home → Magbasa ng bago → Mag-upload → pick a photo of a page; hold the gesture area while "Handa na ang dokumento…" is being said) | Speech stops at once, tone, listening while held; the document does **not** start reading over you; say "basahin", let go → reading starts. Also hold *during* "Binabasa…" (OCR running): never "Hindi gumagana"; at worst "Sandali lang po." | |
| 7 | **Percy** (two-finger swipe left, then hold and ask a question, let go) | Percy hears the whole sentence; it is processed after you let go; Percy is not ended by the hold or the release | |
| 8 | Hold during a long prompt or while the Reader is reading | Speech stops at once; tone; nothing of the prompt is heard as your command | |
| 9 | Hold, say nothing, let go (do it 4 times) | "Wala akong narinig…" each time; never "Hindi gumagana…" | |
| 10 | Short touch (< 0.3 s), tap, double-tap, swipes on the gesture area | Unchanged: tap repeats, double-tap chooses, swipes move; a short touch never listens | |
| 11 | **Airplane mode**, cold start | Loading screen finishes (offline models present); "Handa na po."; commands by hold work offline; no "not working" while loading | |
| 12 | Airplane mode, first launch on a tablet **without** the models (or after deleting them in Pagsusuri ng boses) | The download screen comes first as before (says there is no internet, moves on); then the loading screen | |
| 13 | Slow start: if the loading screen hits 15 s | Says once "May ilang bahagi pa pong naglo-load, pero puwede na po kayong magsimula." and opens the first screen; voice still works (state "naglo-load" until done) | |
| 14 | **TalkBack on**: focus the gesture area, double-tap and hold, speak, let go | Listens (unverified which TalkBack path the tablet uses: if it only listens after a pause instead of on release, report it). TalkBack actions menu still has "Makinig ngayon" | |
| 15 | Tutorial step "Para magsalita ng utos…" | Says the new text (hold while speaking, let go when done); the hold step passes | |

Send back: the load time from test 1 (and 5, 11), and for any failure the `[VOICE …]`,
`[VOICE STATE]` and `[STARTUP]` lines around it (or save them as `voice_log.txt` in the repo
root — it is git-ignored).
