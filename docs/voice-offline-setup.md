# Setting up the tablet for offline voice

For testers. This makes Percipere **listen** and **speak** without internet on the
Samsung Galaxy Tab S10 Lite (works the same on most Android tablets). It takes about
15 minutes and needs Wi-Fi **once**, for the downloads. Afterwards everything in this guide
works in airplane mode.

Menu names differ a little between Samsung updates. If you can't find a menu, open
**Settings**, tap the **magnifying glass** at the top and type the words in **bold**.

---

## What you are setting up

| Part | What it does | Needs to be downloaded once |
|---|---|---|
| Speech recognition | The app **hears** your commands | An "offline speech recognition" language |
| Text-to-speech (TTS) | The app **speaks** to you | A "voice data" language |

Filipino may **not** be available for offline *listening* on this tablet (Google offers only
some languages offline, and the list depends on the tablet). That is fine: download **English
(US)** for offline listening. Without internet, Percipere then listens in English and tells
you once that English commands work best, for example "next", "pause", "library".
With internet, it listens in Filipino as before.

---

## Step 1 — Update the Google speech apps (Wi-Fi on)

1. Open **Play Store**.
2. Search for **Speech Recognition and Synthesis from Google** and tap **Update** (or
   **Install** if it isn't there).
3. Search for **Google** (the Google app) and tap **Update** if offered.

## Step 2 — Let Google do the listening

1. Open **Settings → Apps → Choose default apps → Digital assistant app**.
2. Tap **Voice input** and choose **Speech Recognition and Synthesis from Google**
   (it may be called **Google** or **Speech services by Google**).
   If you can't find it, search Settings for **voice input**.

> Samsung's own voice input may be the default on Samsung tablets. Percipere works with it
> online, but offline it works best with Google's.

## Step 3 — Download offline listening languages

**Easiest way — from Percipere:**
1. Open Percipere → **Mga Setting → Pagsusuri ng boses** (Voice check).
2. If you see **I-download ang offline na Filipino** or **I-download ang offline na Ingles**,
   choose it. A notification shows the download. Wait until it is finished.

**Or from Android:**
1. Search Settings for **offline speech recognition** (or open **Settings → General
   management → Voice input → the gear next to Google → Offline speech recognition**).
2. Open the **All** tab.
3. Download **English (US)**. If **Filipino (Philippines)** is in the list, download it too.
4. Wait until each shows **Installed** (the **Installed** tab).

## Step 4 — Download the voices the app speaks with

1. Search Settings for **text-to-speech output** (usually **Settings → General management →
   Text-to-speech output**).
2. Tap **Preferred engine** and choose **Speech Recognition and Synthesis from Google**
   (not Samsung TTS — it has no Filipino voice).
3. Tap the **gear** next to it → **Install voice data**.
4. Tap **Filipino (Philippines)** → tap the **download** icon next to a voice. Wait until it
   finishes.
5. Do the same for **English (United States)**.
6. Go back and tap **Play** / **Listen to an example** to check you hear a voice.

## Step 5 — Check it in Percipere

1. Open Percipere → **Mga Setting → Pagsusuri ng boses**. The app reads out what it found.
   You want to hear:
   - **Offline na Ingles: oo** (and **Offline na Filipino: oo** if it was available)
   - **Boses: …, naka-install sa tablet** (the voice is on the tablet)
   - **Pahintulot sa mikropono: oo**
2. Choose **Subukan, limang segundo** and say **"buksan ang Aklatan"** after the beep.
   The app reads back what it heard, the command, and the response time in milliseconds.
3. Turn on **airplane mode** and do 1–2 again. **Paraan ng pakikinig ngayon** should say
   **sa tablet mismo** (offline Filipino) or **offline na Ingles**, and the test should still
   work (say **"open the library"** if it's offline English).
4. Turn airplane mode off again when done.

---

## If something doesn't work

| What you notice | What to do |
|---|---|
| Offline, the app says it can't hear you ("walang naka-install…") | Step 3 isn't finished: download **English (US)** and check the **Installed** tab. |
| Offline, the app is silent or skips sentences | Step 4: the voice for that language isn't downloaded. In Voice check, the voice line says **kailangan ng internet**. |
| Prompts are in English although the app is in Filipino | The Filipino *voice* (Step 4.4) isn't installed. The app says so at start. |
| The app reacts slowly | In Settings, check the **speech speed**: "Mabagal" makes every prompt longer, and the app listens only after it stops talking. Try "Katamtaman". |
| Commands are missed in a noisy room | Hold the tablet closer, speak right after the beep, and use short commands. If unsure, the app asks "Ito ba ang ibig mong sabihin…?" — answer "oo" or "hindi". |
| Voice check says **Pagkilala sa boses: Samsung** | Do Step 2. |
| After installing, nothing changed | Close Percipere completely (swipe it away from recent apps) and open it again. |

For developers: the tablet's log shows `[VOICE]` lines (`adb logcat -s flutter`), including
the listening plan (`locale=… onDevice=… online=…`) and the recognizer's offline languages.
