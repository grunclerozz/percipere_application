# Offline voice — what testers need to know

Since 2026-10-15 Percipere **sets up offline voice by itself**. Nobody has to install
anything from Google or change Android settings. At first launch the app downloads its own
voices and its own command recognizer **once** (about **86 MB**), and from then on voice
commands and reading aloud work in **airplane mode**, in Filipino and English.

(Percy's free conversation and dictation — names, email, passwords — still use Android's
recognizer and need internet unless Android has an offline language installed. That is
planned for later: `docs/todo.md`.)

---

## Before the test: the server

The app downloads the models from the dashboard server, or — if the server can't be
reached — from the GitHub release `voice-models-v1`.

1. Put the three archives and `manifest.json` in the dashboard's `models/` folder
   (`tool/voice_models/README.md`, "Putting them on the server").
2. In a browser on the tablet, open `http://<server>/percipere_dashboard/models/manifest.json`
   — you should see the list. (This checks the tablet reaches the PC.)

## First launch

1. Install the APK and open Percipere **with Wi-Fi on**.
2. Before Welcome, the app says **"Pakihintay habang dina-download namin ang mga boses at
   wika."** and the size ("Mga 86 megabyte ito; isang beses lang.").
3. About every 20 % it says the progress ("20 porsiyento na." …).
4. At the end: **"Handa na. Gumagana na ang boses kahit walang internet."** Then Welcome
   (and later the tutorial) continue as usual.
   - In a hurry? Say **"ituloy"** (or choose **Ituloy habang nagda-download**): the app goes
     on and keeps downloading; it says "Handa na…" when it is done.
   - **No internet?** The app says so once and goes on. Gestures work, and voice works while
     there is internet. When the internet comes back the download continues by itself, from
     where it stopped.
   - **Not enough space?** The app says how many megabytes it needs. Free some space; the app
     tries again when the connection changes, or choose **Subukan ulit**.

## Checking it — Settings → "Pagsusuri ng boses"

The first line is **"Sariling offline na boses at utos ng Percipere: naka-install, bersyon
1, 1, 1."** Other answers: *nagda-download, … porsiyento*, *naghihintay ng internet*,
*kulang ang espasyo*, *hindi pa naka-download*.

- **Paraan ng pakikinig ngayon: offline, sariling makina ng Percipere** — commands use the
  app's own recognizer (also when online).
- **Makina ng boses: Percipere offline** — prompts use the app's own voice. If the tablet
  already has an *installed* Google voice for the language, that one is used instead (it
  sounds better); a voice that needs the internet is never used offline.
- **Subukan, limang segundo** — say "buksan ang Aklatan" after the beep; the app reads back
  what it heard, the command and the response time.
- **I-download ulit ang mga boses** — deletes the models and downloads them again.
- **Burahin ang mga offline na boses** — asks first ("oo" / "hindi"), then deletes them
  (voice falls back to Android's until they are downloaded again).

## Airplane-mode test

1. Turn on **airplane mode**.
2. Say commands in **Filipino** ("susunod", "bumalik", "buksan ang Aklatan", "basahin",
   "itigil") and in **English** ("next", "go back", "open the library", "pause").
3. Open a document and let it be **read aloud** (Filipino and English text); try "i-pause" /
   "pause" while it reads.
4. If unsure, the app asks **"Ito ba ang ibig mong sabihin…?"** — answer "oo" or "hindi".

## If something doesn't work

| What you notice | What to do |
|---|---|
| No "Pakihintay…" at first launch | The models were already there, or the screen was shown before on this tablet (it shows once; later downloads run silently). Check Pagsusuri ng boses. |
| The download stays at 0 % | The tablet can't reach the server or GitHub. Check the manifest URL in the tablet's browser; check the server address (developer build: Settings → Server address). |
| "hindi natapos ang pag-download" | A file was damaged or the server sent an error. Choose **I-download ulit ang mga boses**; check the archives' sizes against `manifest.json`. |
| Commands are often misheard | Speak right after the beep, close to the tablet, one command at a time. Note which words fail (the log shows `[OFFLINE VOICE] heard "…"`), so the matcher's phrases can be tuned. |
| The first prompt after opening the app is late | The voices load in the background at start (a few seconds). Later prompts start faster. |

For developers: `adb logcat -s flutter` shows `[OFFLINE VOICE]` lines (download, loading
times, what the recognizer heard and how long it took) and `[VOICE]` lines with
`offline=true` for sessions that used the app's own recognizer.

---

## Optional: Google's offline packs

Not needed any more. If a tablet already has Google's offline speech or voice data
installed, Percipere still uses the **installed Google voice** for speaking (it sounds
better), while commands always go to the app's own recognizer first. Percy and dictation
use Google's recognizer, which works offline only with its offline language pack
(Settings → search "offline speech recognition").
