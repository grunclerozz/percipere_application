# Document inputs + "questions wait for the answer" — tablet checklist (2026-10-07)

Keep the log running on the PC the whole time:

```
adb logcat -s flutter | findstr CAPTURE
```

## 0. Remove the old app first (important)
The application id changed today, so the new APK does **not** replace the old one: both
can be installed, both called "Percipere".

- [ ] Android Settings → Apps: uninstall **every** "Percipere" (or
      `adb uninstall ph.bataan.percipere` and `adb uninstall ph.bataan.percipere.app`).
- [ ] Install the new build. Settings → Apps → Percipere shows **version 0.1.1**.
- [ ] Open the app. The log's first CAPTURE line says
      `[CAPTURE] app ph.bataan.percipere.app 0.1.1+2 (debug build)` — or `(release build)`
      for the APK. If you don't see this line, you are running an old build.

## 1. Inputs — do this twice: `flutter run` (debug), then the release APK
For each one: the Reader opens, says "Handa na ang dokumento…", reads it, and the item is
in the Aklatan afterwards.

- [ ] **Camera** (Magbasa ng bago → Gamit ang Camera): photo of a printed page.
- [ ] **Gallery image** (Mag-upload → a JPG or PNG from Photos/Gallery).
- [ ] **Image from Downloads / Files app** (Mag-upload → Browse → Downloads).
- [ ] **PDF with text** (e.g. a downloaded document).
- [ ] **Scanned PDF** (pages are pictures): slower, page progress is spoken.
- [ ] **DOCX** (a Word file).
- [ ] **A file from Google Drive** in the picker, if the tablet has Drive.
- [ ] **Maglarawan** → Mag-upload → an image: the description is spoken.
- [ ] Open the picker and press back without choosing: "Walang napiling file." (only here)

If anything fails, note **what you heard** and send me the CAPTURE lines. Each failure now
has its own message:

| You hear | Meaning |
|---|---|
| "Walang napiling file." | The picker was closed without a choice (only that). |
| "Hindi ko makuha ang file na pinili mo…" | A file was chosen but couldn't be copied/read. |
| "Hindi mabuksan ang file na ito. Maaaring sira ito." | The file itself is damaged or isn't what its name says. |
| "Nagkaproblema habang binabasa ko ang file. Malamang hindi ito sira…" | The app failed for another reason — the log has the cause. |
| "Hindi gumana ang pagbasa ng teksto…" | The text recognizer (ML Kit) failed. |
| "Nawala ang file bago ko ito nabasa…" | The file disappeared before reading. |
| "…pero hindi ko ito na-save sa Aklatan." | Reading works, saving to the Library failed. |

## 2. Questions wait for the answer
- [ ] **Home**: you hear "Home. Ano ang gusto mong gawin? Mga pagpipilian: …" and then
      **silence**. In voice mode the app listens right away.
- [ ] Say nothing: after about **6 seconds** you hear how to navigate (the mode hint).
- [ ] Open Home again and **answer straight away** (say "aklatan" or swipe): the
      instructions are never spoken.
- [ ] **Capture**: question + options, silence; the Maglarawan sentence comes only if you
      wait.
- [ ] **Delete a collection** (Aklatan → collection → burahin): "Burahin ang koleksyong …?
      Hindi mabubura ang mga laman nito." is said together; "I-double tap o sabihin ang
      'oo'…" only after the pause. Answer "oo" before it: it is deleted, no instructions.
- [ ] **Setup** (Profiling): each step asks its question (with the current value, e.g.
      "Laki ng teksto: 18"), then waits; the "mag-swipe pataas…" instructions come only if
      you wait.
- [ ] Start answering by voice just before the 6 s are up: the instructions don't talk
      over you.
- [ ] Is 6 seconds right? Too long or too short → tell me (`VoiceConfig.answerWait`).

## 3. Quick regression
- [ ] Reader: read, pause, next/previous sentence, back saves the position.
- [ ] Voice commands and gestures on Home, Capture, Aklatan, Settings.
- [ ] Settings changes are kept after closing and reopening the app.
