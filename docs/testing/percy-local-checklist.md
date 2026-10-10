# Percy (self-built) — tablet checklist (Phase 9)

Spec: `docs/specs/percy-local.md`. Log: `adb logcat -s flutter | findstr PERCY` shows each
sentence, the top 3 intents with probabilities, and the time (ms).

Before you start: install the new APK (uninstall the old `ph.bataan.percipere` app if it is
still there), log in, and **turn Wi-Fi off** for the first round (Percy must work offline).

## Starting and ending
- [ ] Home, two-finger swipe left → "Hello po, ako si Percy…" (no internet needed).
- [ ] Gesture mode: after Percy speaks, the app listens without a long-press.
- [ ] Say "Percy, buksan mo ang library" from Home without starting Percy first → Library opens.
- [ ] "Paalam na Percy" → goodbye; afterwards a swipe works normally again.
- [ ] While Percy is on, any swipe or tap ends Percy ("Tapos na po ang usapan natin") and does
      nothing else.
- [ ] Stay silent for a minute → Percy ends by itself (not while a document is being read).

## Understanding (try your own words too)
- [ ] "dalhin mo ako sa library", "punta tayo sa settings", "bumalik ka" → act.
- [ ] Short commands ("home", "bilisan", "i-pause") still act at once.
- [ ] A vague sentence → "Ang ibig mo po bang sabihin ay …?" → "oo" acts, "hindi" / "wag na"
      doesn't.
- [ ] Something out of scope ("anong panahon bukas", "kumanta ka") → "Hindi ko pa po kaya
      iyan. Pwede mong sabihin: …" with suggestions for this screen.
- [ ] Reader: "pakibilisan", "ulitin mo", "susunod" (next sentence), "i-pause mo".
- [ ] Home: "bilisan mo" → "Hindi po iyan magagawa sa screen na ito."
- [ ] "Nasaan ako?" → the screen and focused option.

## Documents (open_item)
- [ ] "buksan mo yung [a title in your Library]" → opens it; "basahin mo yung …" starts reading.
- [ ] Two similar titles → "Alin po sa mga ito: …?" → "yung pangalawa" opens the second.
- [ ] "may bubuksan ako" → Percy lists up to 3 recent documents and asks which.
- [ ] A title that doesn't exist → "Wala po akong nakitang …" + offer to open the Library.
- [ ] "buksan ang huli" → the most recently opened document.

## Confirmations
- [ ] Library item → "Burahin": the app's question is **spoken**; "hindi" keeps it, "oo" deletes.
- [ ] Settings → Logout: same.

## Settings
- [ ] "Paraan ng pagsalita ni Percy": Magalang (po) / Kaswal changes the "po".
- [ ] "Haba ng sagot ni Percy": Maikli (no "Sige po" before actions), Katamtaman, Madaldal
      ("May iba pa po ba?").
- [ ] "I-save ang usapan kay Percy" off → nothing new is logged.
- [ ] English app language → Percy answers in English.

## Developer build only (`flutter build apk --release --dart-define=PERCIPERE_DEV=true`)
- [ ] Settings shows "Percy online (ElevenLabs, developer)" (off) and "I-export ang log ni
      Percy (CSV)".
- [ ] Export → share sheet with `percy-stt-log-<date>.csv`; columns `text,intent,author,source,notes`,
      `source = STT log`.
- [ ] With the ElevenLabs switch on (and internet), the swipe calls the online Percy with its
      consent question; with it off, nothing is sent to ElevenLabs.

## Timing
- [ ] In the log, `[PERCY] ... in X ms` stays under 20 ms per sentence; the first start
      (model loading) is logged once as `model ... loaded in N ms`.
