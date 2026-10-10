# Voice latency, speed strip, reading voice — tablet checklist (2026-10-10)

Log: `adb logcat -s flutter | findstr "VOICE TTS"`. In a debug build, `[VOICE TIMING]` shows
`SPEECH START→ACTION` and `END OF SPEECH→ACTION` per command (release builds don't print it).
Tuning values: `lib/config/voice_config.dart` (`commandPause` = 1.0 s, `cutOffRetries` = 3,
`carryWait`, `duckMax`).

## 1. Voice commands
- [ ] Voice mode: after each prompt, a short soft blip sounds when the microphone opens.
      Silent restarts (nobody spoke) have no blip.
- [ ] Short commands ("i-pause", "susunod", "bumalik") act before you finish the pause.
- [ ] The first command after opening the app works at once (recognizer prepared at start;
      log: `initialized in N ms` appears on the first screen, not at the first command).
- [ ] Start a command just as a prompt begins, or while another app takes the audio:
      the words already said show under the waveform, listening restarts, and finishing
      the sentence runs the whole command.
- [ ] Say part of a command and stop: it is acted on (not silently dropped).
- [ ] Keep getting cut off (e.g. play music in another app): after 3 restarts you hear
      "Pasensya na po, pakiulit." and a buzz.
- [ ] Reader, voice mode, "Makinig habang nagbabasa" on: talk over the reading → it pauses
      at once; a reading command ("i-pause", "bilisan") does that; anything else → reading
      continues from the start of the sentence it was on.
- [ ] The reading never keeps restarting the same sentence by itself (echo).

## 2. Speed strip (right edge of the Gesture Area, every screen)
- [ ] It shows "2.0x" + up arrow at the top, "Bilis" and the current value in the middle,
      "0.5x" + down arrow at the bottom; readable in every theme and text size.
- [ ] Slide up: a tick per 0.25 step, and "Bilis 1.5" spoken once when the finger stops
      (a fast slide doesn't queue several values). Slide down: slower.
- [ ] At 2.0x / 0.5x it buzzes and stays.
- [ ] While a document is being read: the value is said between sentences and reading goes
      on at the new speed at once.
- [ ] The speed is kept after closing and reopening the app.
- [ ] Swipes in the gesture area (next/back, up/down) never change the speed; sliding on the
      strip never moves focus or goes back.
- [ ] TalkBack on: the strip reads "Bilis, 1.0 na beses"; swipe up/down on it (or the
      actions menu: "Bilisan" / "Bagalan") changes it.

## 3. Reading voice (Settings → "Boses sa pagbasa", then "Pakinggan ang boses")
- [ ] If the phone's voices tell their gender: the row cycles Babae / Lalaki; otherwise it
      lists "Boses 1 (…)", "Boses 2 (…)"; with only one voice it says so and can't change.
- [ ] Changing it says "Napalitan na ang boses: babae." in the new voice.
- [ ] "Pakinggan ang boses" plays a sample at your reading speed.
- [ ] The Reader and all prompts use the chosen voice; it is kept after restarting the app.
- [ ] English app language: the list shows English voices.
