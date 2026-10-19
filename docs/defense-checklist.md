# Defense checklist

> **Changed 2026-10-19:** the app no longer has an "Address ng server" setting. The dashboard
> address is fixed when the app is built: `flutter build apk --release --dart-define=API_BASE_URL=http://<IP>/website/percipere_dashboard`
> (without it the app uses the emulator's `http://10.0.2.2/website/percipere_dashboard`). A new
> IP means a new build. Ignore checklist lines below that type the address in the app.



Plain steps for the team. Network details: `docs/connection-guide-app.md`. Demo order:
`docs/demo-script.md`. Tablet tests to finish first: §19 of `docs/testing/system-test-checklist.md`.

## Days before
- [ ] The last tablet round is done and its bugs are fixed (`docs/testing/system-test-checklist.md`).
- [ ] Release APK built **with** the demo settings (see "Build" below) and installed on the tablet.
- [ ] Offline voice models uploaded (dashboard `models/` folder + `manifest.json`) and downloaded once
      on the tablet (Settings → Pagsusuri ng boses shows the models as installed). Without this the
      offline voice does not work.
- [ ] Test account created; the same account logged in on the tablet. Guest mode as a spare.
- [ ] At least one admin book on the dashboard and **downloaded** on the tablet (Aklatan).
- [ ] A few printed pages, one blurry/dark sample photo and one picture for Maglarawan, ready on paper.

## Night before
- [ ] Charge the tablet, the MacBook, the hotspot phone, the earphones with mic. Pack chargers.
- [ ] Install the release APK on the tablet (`adb install` is for the team, not an agent).
- [ ] Open the app once on the tablet: Filipino voice speaks, one voice command works.
- [ ] Tablet volume up; "Do not disturb" on; auto-updates and screen timeout set to long.
- [ ] Copy the backup (below) to the flash drive.

## 1 hour before
- [ ] Start **MAMP** on the MacBook (Apache and MySQL green). Dashboard opens in the browser.
- [ ] Turn on the hotspot. Connect the **tablet and the MacBook to the same hotspot**.
- [ ] Find the MacBook IP again (`ipconfig getifaddr en0`). It changes between places.
- [ ] Tablet browser: `http://<IP>/<dashboard folder>/api/v1/health` shows `"status":"ok"`.
- [ ] App → Settings → **Address ng server** → type `http://<IP>/<dashboard folder>` → I-save.
- [ ] **Subukan ang koneksyon sa server** says "Nakakonekta sa server."
- [ ] Open **Aklatan**: it says it is connected; the admin books are listed.
- [ ] Test **one voice command** (for example "Basahin"), hold-to-listen once, and one Percy question.
- [ ] Quiet-room test of the earphone mic; then say one command with room noise.

## If the server fails
1. Read the spoken reason (`docs/connection-guide-app.md` §4) and fix it: same hotspot, MAMP green,
   MacBook firewall, correct IP, no VPN.
2. **Cloudflare quick tunnel** (`docs/connection-guide-app.md` §5): `cloudflared tunnel --url http://localhost:80`
   (use the MAMP port if different). Put the printed `https://….trycloudflare.com` address (plus the
   dashboard folder) in **Address ng server**; test again. The tablet needs internet for this.
3. **Offline demo path** (needs no server, no internet; turn on airplane mode to prove it):
   - scan or upload a page and have it **read aloud** (Reader);
   - **gestures** (Gesture Pad) and voice commands with the offline voice;
   - **Percy** (rule-based, offline);
   - **downloaded books** in Aklatan;
   - **Maglarawan offline** (on-device labels; the online description is skipped).
   Say plainly: "Account sync, new books and reports need the server; the rest works offline."

## Backup
- [ ] Release APK on the flash drive (and in the cloud).
- [ ] The demo APK's build command written down (below).
- [ ] Screen recordings of each feature (Reader, gestures, voice, Percy, Maglarawan, Aklatan,
      Report an issue) on the flash drive and on the MacBook.
- [ ] Printed copy of `docs/demo-script.md` and `docs/thesis/algorithms.md`.
- [ ] Second tablet or phone with the APK installed, if available.
- [ ] `cloudflared` installed on the MacBook (`brew install cloudflared`).

## Build (for whoever builds the APK)
A JDK must be available to Flutter (`JAVA_HOME`). From the project folder:

```
flutter build apk --release --dart-define=PERCIPERE_DEV=true --dart-define=API_BASE_URL=http://<MacBook IP>/<dashboard folder>
```

`PERCIPERE_DEV=true` shows the "Address ng server" row and the connection test (needed at the
defense). `API_BASE_URL` is only the first default; the address can be changed in the app.
No secrets in these values.

## Honest limits to know before questions
- Almost everything since 2026-10-07 was built before its tablet test; use the §19 results.
- Percy's evaluation numbers are **provisional** until the team's test phrases are in.
- Photo-quality thresholds are tuned by hand (unverified); no WER table yet (it comes from the study).
- Future work (say so if asked): ElevenLabs voice, switching the vision AI provider, heavy
  noise-cancellation models, Aklatan EPUB image descriptions, SUS/usage logs/sync.
