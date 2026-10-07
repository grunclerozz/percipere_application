# Voice response time — tablet checklist

Test in **voice mode** (Settings → Paraan ng pag-navigate → Pa-boses), first with the tablet
speaker, then with earphones. Keep the logs running on the PC while you test:

```
adb logcat -s flutter | findstr VOICE
```

Each command prints one line like:

```
[VOICE TIMING] "itigil" via partial while reading → stopSpeech | … | END OF SPEECH→ACTION 240ms
```

**END OF SPEECH→ACTION** is the number to watch (target: under 1000 ms). "via partial" means
the app acted before the recognizer finished; "via final" means it waited for the pause.
Send me a few of these lines if something feels slow.

## 1. Response time (any screen)
- [ ] On Home, say **"aklatan"**. You hear a short beep and feel a short buzz right away,
      then the Library opens. The beep comes before the screen changes.
- [ ] Say **"bumalik"**, **"settings"**, **"bumalik"**, **"home"**: each one feels quick
      (well under a second after you stop talking).
- [ ] Say **"susunod"** on a list: it still works (it waits about 1 second, because
      "susunod na talata" starts the same way).
- [ ] Say a long command slowly, with a short pause in the middle: **"basahin … mula sa
      simula"** (Reader). If it gets cut off after "basahin", tell me: the command pause
      (1.2 s) may need to be longer.

## 2. Forms still give you time (dictation)
- [ ] Register: dictate the first name, the email (spell it slowly: "j u a n at gmail dot
      com") and a password. Pausing 2 seconds in the middle does **not** cut you off.
- [ ] Library: "gumawa ng koleksyon na …" → dictate a two-word collection name slowly.
- [ ] Library: **"ituloy ang liham kay nanay"** (or another title) said at normal speed
      opens the right item. It must **not** run "ituloy" alone before you say the title.
- [ ] Library: **"hanapin bata"** searches; it does not stop after "hanapin".

## 3. No double or stale commands
- [ ] Say **"bumalik"** once: you go back **one** screen, never two.
- [ ] Say **"susunod"** once on a list: focus moves **one** item.
- [ ] Say **"itigil, bumalik"** in one breath: only the first ("itigil") runs.
- [ ] Swipe right while saying "bumalik": the swipe runs; the "bumalik" said during the
      swipe is ignored (say it again after the swipe and it works).
- [ ] Spam: say "bilisan bilisan bilisan" fast. The speed changes in sensible steps, with no
      backlog of commands running after you stop.

## 4. Listening while reading (barge-in) — the most important part
Open a long document in the Reader and let it read. **While it is speaking**, say each of
these (clearly, normal volume, about 30 cm from the tablet):

| Say | Expected (within about 1 second) |
|---|---|
| **"i-pause"** (or "pause", "sandali") | Reading pauses. Then say "ituloy" to continue. |
| **"itigil"** (or "stop", "tigil") | Reading stops. |
| **"bilisan"** (or "faster") | Faster; reading continues. |
| **"bagalan"** (or "slower") | Slower; reading continues. |
| **"palakihin"** / **"paliitin"** | Text bigger / smaller. |
| **"paborito"** (or "favorite") | "Na-save bilang paborito", reading continues. |
| **"ulitin"** (or "repeat") | Repeats the sentence. |
| **"bumalik"** (or "back") | Leaves the Reader and saves your place. |

Then check that it does **not** react to things it shouldn't:
- [ ] Say **"susunod"**, **"camera"** or **"settings"** while it reads: nothing happens
      (only reading commands work during reading). They work again once reading is paused.
- [ ] Let it read for **2–3 minutes without speaking**, on the tablet speaker. It must not
      pause, stop, or change speed by itself, and must never say "Hindi ko naintindihan".
      Note any false trigger and the sentence it was reading (the log shows it).
- [ ] Read a document that contains the words "sandali", "balik", "ulit" or "tigil" (type
      a short note in a text file and upload it). The app must not pause itself when it
      reads those words.
- [ ] Listen for recognizer beeps from the phone over the reading. If the tablet beeps every
      few seconds, tell me.
- [ ] The reading volume stays the same while the app listens (some phones turn media
      down while the speech recognizer is on). If the voice gets quieter, tell me.
- [ ] Repeat the table above **with earphones**; it should be at least as reliable.
- [ ] Settings → **Makinig habang nagbabasa** → Naka-off. Now commands spoken during reading
      are ignored, and the app listens again only after reading pauses (as before).
- [ ] Reader help (three-finger tap) mentions the reading commands and recommends earphones.

## 5. Long-press (always works)
- [ ] While it reads, **long-press the gesture area**: speech stops **at once** and it
      listens. Say "ituloy": reading continues from the same sentence.
- [ ] Same in **gesture mode**: long-press stops the reading and listens once.
- [ ] Long-press while a prompt is being spoken: the prompt stops and it listens.

## 6. Regressions (the listening loop from the stabilization pass)
- [ ] Leave the app idle in voice mode for over a minute: it says listening is paused (no
      endless beeping); long-press re-arms it.
- [ ] Airplane mode with the offline speech pack installed: commands still work.
- [ ] Put the app in the background and back: listening resumes.
- [ ] No "error_busy" loops in the log (`findstr busy`): if you see several in a row,
      tell me (the 200 ms gap in `voice_config.dart` may need to be longer).
