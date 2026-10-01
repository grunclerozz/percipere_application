# Phase 6B: manual test checklist (voice and gestures)

Run on the emulator or a phone with the Filipino TTS voice installed. Start from a fresh
install (uninstall first) unless a step says otherwise. Each screen must announce itself;
every action gets spoken (and, with vibration on, haptic) confirmation.

**Gestures** (on the Gesture Pad; on Welcome and setup Step 1, anywhere on screen):
swipe right/left = next/previous, double-tap = press / submit / confirm, tap = repeat,
long-press = speak, two-finger swipe right = back, three-finger tap = help.

## 1. Welcome
- [ ] Hears "Welcome. Meron ka na bang account? Kung wala pa, mag-register ka." and how
      to choose by gesture; then the microphone explanation and Android dialog (first
      launch only). Allow → "Maaari mo nang sabihin ang “login”, “register”, o
      “subukan”."
- [ ] Gesture: swipe right → "Login, 1 sa 3", again → "Register, 2 sa 3", again →
      "Subukan muna (Try first), 3 sa 3"; double-tap opens the focused one.
- [ ] Voice: "login", "register", "subukan" each open the right screen.
- [ ] Back (two-finger swipe right, "bumalik", or Android back): "Nasa simula ka na.
      Gusto mo bang isara ang app?" — double-tap / "oo" closes; anything else stays.
- [ ] Refuse the microphone on a fresh install: gestures still work; the prompt only
      describes gestures.

## 2. Register
- [ ] Hears "Register. Sagutin ang bawat tanong…" then "Ano ang iyong pangalan (first
      name)?"
- [ ] Voice: say the first name → read back ("First Name: Juan.") and the next question;
      last name; email spelled ("juan at gmail dot com" → juan@gmail.com); password →
      only "Password: 12 titik." (never the password; not shown under the waveform).
- [ ] "tapos na" (or double-tap) submits.
- [ ] Gesture: swipe right/left moves between fields ("Email Address: …, 3 sa 5");
      long-press dictates the focused field; tap repeats its question.
- [ ] Typing: tap a field, type, press Done → the same read-back, next field focused.
- [ ] Errors spoken: empty fields ("Kulang pa: …"), bad email, password < 8, an email
      already registered on the phone.
- [ ] Back with something typed: "May hindi pa naka-save. Sigurado ka bang babalik?"
- [ ] After submit: security question list (swipe + double-tap, or say e.g. "bayan"),
      answer by voice or typing, "submit".
- [ ] Phone with a fingerprint enrolled: "Gusto mo bang gamitin ang iyong fingerprint…"
      Oo → fingerprint prompt; Hindi / back → setup.

## 3. Guided setup (after Register)
- [ ] Each step says "Hakbang N ng 10", the question, and how to answer.
- [ ] Step 1 (Welcome-style screen): "boses"/"galaw", or swipe + double-tap.
- [ ] "Nakakakita ka ba ng kahit kaunting teksto…": Hindi → jumps to Step 4.
- [ ] Step 2 text size: swipe up/"palakihin", down/"paliitin"; sample text changes
      live; "Laki ng teksto: 24."; error buzz + "Hanggang dito na lang." at 18 and 48.
- [ ] Step 3 text color: swipe right/left or "susunod"/"nakaraan"; Filipino color name
      spoken; sample changes live.
- [ ] Step 4: swipe to each option to hear a sample in that voice; "Tagalog"/"Ingles".
- [ ] Step 5 speed / Step 6 tone: swipe up/down or "bilisan"/"bagalan",
      "taasan"/"babaan"; sample spoken at the new value (0.25 steps).
- [ ] Step 7 theme: swipe → the whole screen changes; with a cream-only text color
      chosen, "Pinalitan ang kulay ng teksto para mas mabasa."
- [ ] Step 8 vibration: focusing Oo buzzes; Hindi turns haptics off app-wide.
- [ ] Step 9 auto-read: Oo / Hindi.
- [ ] Every step: tap/"ulitin" repeats, "laktawan" keeps the default, back
      (two-finger swipe right / "bumalik") returns a step with values kept,
      double-tap/"okay"/"sige" confirms.
- [ ] Summary: list read aloud; "bumalik sa bilis" (or swipe to it + double-tap) opens
      that step and returns to the summary; "oo"/double-tap → "Tapos na ang setup." →
      Capture.
- [ ] Close the app in the middle of the setup, reopen: it resumes at the same step.

## 4. Login
- [ ] From Welcome → Login: hears the submit hint and "Ano ang iyong email address?"
- [ ] Voice and typing as in Register; double-tap / "submit" / "tapos na" logs in →
      "Maligayang pagbabalik, …" → Capture (or the setup if never finished).
- [ ] Wrong password: "Mali ang email o password. N pang subok…"; 5th wrong → "Maghintay
      ng 30 segundo…", countdown spoken (20, 10, 3, 2, 1), "Maaari ka nang sumubok
      muli."; the next wrong one locks for 60 s. Survives closing the app.
- [ ] "nakalimutan" → Forgot password: admin note spoken; email → security question →
      wrong answer refused → right answer → new password → back on Login.
- [ ] With fingerprint on: the fingerprint prompt appears on entry; cancel → password
      asked; "fingerprint" tries again.

## 5. Subukan muna (guest)
- [ ] Short setup: "Hakbang 1 ng 4" (navigation, voice, speed, summary).
- [ ] Reading and settings work. After the first document is saved, the next time
      Capture opens: "Naka-save ito sa phone na ito lamang. Mag-register para hindi ito
      mawala." (once). Also once on the first Settings visit. Never while reading or
      during setup.
- [ ] Settings → "Register": after registering, settings and history are kept and only
      the remaining setup steps are asked ("Hakbang 1 ng 7").
- [ ] Logout as guest → Welcome; "Subukan muna" again reuses the same guest.

## 6. Capture, Reader, History
- [ ] Auto-read on: after an upload/scan the document is announced and reading starts.
- [ ] Auto-read off: "…Mag-double-tap para simulan ang pagbasa…"; double-tap or
      "basahin" starts.
- [ ] Reader: double-tap read/pause, tap repeats the sentence, two-finger swipe down/up
      next/previous paragraph, swipe up/down speed (0.25 steps).
- [ ] Back while reading: reading stops, "Bumalik sa Pagkuha ng dokumento.", reopening
      from History resumes at the same sentence.
- [ ] History shows only the logged-in user's documents.

## 7. Settings
- [ ] New rows: Tema, Kulay ng teksto, Laki ng teksto (18–48), Awtomatikong pagbasa,
      Manatiling naka-login, Fingerprint login, Ulitin ang setup, Logout.
- [ ] Theme change with a color the new theme lacks → "Pinalitan ang kulay…".
- [ ] "logout" (voice) or double-tap on Logout → "Sigurado ka bang gusto mong
      mag-logout?" → "oo" → "Nais mo bang mag login sa iyong account?" (Login/Register).
- [ ] "Manatiling naka-login" off → after restarting the app: "Natapos na ang iyong
      session. Nais mo bang mag login…", the text size/theme unchanged.
- [ ] "ulitin ang setup" → all 10 steps; finishing returns to Settings.

## 8. Back everywhere
- [ ] On every screen the three ways behave the same: two-finger swipe right,
      "bumalik" / "bumalik ng page" / "go back", and Android back (button or edge
      swipe). The destination is announced ("Bumalik sa …").
- [ ] "nakaraan" / "previous" never goes back a screen (previous option/sentence only).

## 9. Old PIN accounts (upgrade from Phase 6)
- [ ] Install the Phase 6 build, create a PIN profile and stay logged in, then install
      this build: the app asks for an email and password ("I-update ang account"),
      then a security question, then the setup; settings and history are kept.
- [ ] Logged-out PIN profile: Login → "Lumang account (PIN)" → choose it → old PIN →
      same upgrade.
