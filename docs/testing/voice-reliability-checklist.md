# Voice reliability — tablet test (2026-10-17, branch `fix/voice-reliability`)

What was fixed: commands that had to be said twice, the hold that had to be done twice, the
false "Hindi gumagana ang pakikinig ng boses ko ngayon" message, and unsure commands in noise.
Background: `docs/handoff/03-voice-and-percy.md` → "Voice reliability".

Build with the developer rows (needed for the 20-command test):

    flutter build apk --release --split-per-abi --dart-define=PERCIPERE_DEV=true <your usual defines>

Install `app-arm64-v8a-release.apk`. Keep `adb logcat -s flutter` running if you can: the
`[VOICE …]`, `[OFFLINE VOICE]` and `[VOICE TRIAL]` lines explain any failure.

## 1. The 20-command test (repeatable, logged to CSV)
Settings → **Pagsusuri ng boses** → (developer rows at the bottom).
1. Quiet room: **"Pagsubok ng 20 utos: tahimik na kuwarto"**. The app says
   "Utos 1 ng 20. Sabihin po: susunod", then the short "listening" tone. Say the command
   **after the tone**. If it doesn't match it says "Hindi po tugma. Pakiulit po: …" (up to 3 tries).
2. Noisy room (TV or radio on at normal volume, or people talking 1–2 m away):
   **"Pagsubok ng 20 utos: maingay na kuwarto"**. Same steps.
3. **"I-share ang resulta ng pagsubok (CSV)"** → send the file to yourself.
   To stop a round early: "Ihinto ang pagsubok" (or leave the screen); rows so far are kept.

The file `voice-trials.csv` (app storage; rounds are appended) has one row per command:
`timestamp, room, number, expected_phrase, expected_command, recognized_text, matched_command,
correct, attempts, response_ms, listen_ms, total_ms, engine, noisy_detected, confidence`.
- `attempts`: 1 = first try (the goal). `correct` 0 after 3 tries = failed.
- `response_ms`: end of speech → command known (Android path; near 0 on the offline path, which
  has no partial results). `listen_ms`: microphone open → result. `total_ms`: whole command.
- `engine`: `offline` (the app's own recognizer), `android-device`, `android-online`.
- `noisy_detected`: the app judged the room noisy (used for "Medyo maingay po…").

Write down per room: correct on 1st try (x/20), total correct (x/20), median `listen_ms`.

## 2. Problems from before — check each one
| # | Do | Expected |
|---|---|---|
| 2.1 | Voice mode, Home. Say "susunod" **once** right after the tone, 10 times | Each runs the first time |
| 2.2 | Gesture mode. Hold one finger on the gesture area (≈ 0.7 s) → tone → say "aklatan". 10 times | Every hold gives the tone and listens; never "Wala akong narinig" at once |
| 2.3 | Hold twice quickly | Still one session (no on-off) |
| 2.4 | Use voice for 10 minutes in normal use | Never "Hindi gumagana ang pakikinig…" while commands still work |
| 2.5 | Tone timing | The tone plays when the app can really hear (it may come ~0.3 s later than before) |

## 3. Hold while the app talks
| # | Do | Expected |
|---|---|---|
| 3.1 | Percy speaking a long answer → hold | Percy stops at once, tone, it listens; Percy's old answer is not spoken after |
| 3.2 | Reader reading → hold → "ituloy" | Reading stops, listens, "ituloy" goes on from the interrupted sentence |
| 3.3 | A prompt being spoken → hold | Prompt stops; no prompt starts again over the listening |

## 4. Noisy room
| # | Do | Expected |
|---|---|---|
| 4.1 | TV on. Say a command slightly wrong or mumbled (e.g. "bilisa…") | "Medyo maingay po. Ito po ba ang ibig ninyong sabihin: “bilisan”? …" → "oo" runs it |
| 4.2 | Quiet room, same mumble | "Hindi ko po naintindihan" / suggestions as before (no change) |
| 4.3 | Percy in noise | Percy's own confidence rules are unchanged |

## 5. Offline / airplane mode
| # | Do | Expected |
|---|---|---|
| 5.1 | Airplane mode, models installed. Voice mode: 10 commands | Commands work (engine `offline` in the CSV); tone after the mic is live |
| 5.2 | Airplane mode, run the 20-command quiet test | CSV rows with `engine=offline` |
| 5.3 | Airplane mode, hold 5 times | Every hold listens |
| 5.4 | Airplane mode, dictation (e.g. collection name) | As before: needs Android's offline pack, else the offline message |

## Send back
The CSV file, and for any failure the time it happened plus the `adb logcat -s flutter` lines
around it (look for `stale`, `giving up`, `microphone live`, `no sound from the microphone`).
