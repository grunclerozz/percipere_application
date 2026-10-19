# Connecting the tablet to the dashboard (for the defense)

> **Changed 2026-10-19:** the app no longer has an "Address ng server" setting. The dashboard
> address is fixed when the app is built: `flutter build apk --release --dart-define=API_BASE_URL=http://<IP>/website/percipere_dashboard`
> (without it the app uses the emulator's `http://10.0.2.2/website/percipere_dashboard`). A new
> IP means a new build. Ignore the steps below that type the address in the app.

For students, no programming needed. The app talks to the dashboard (the website part) over the
network. **Only the server address changes** between places; you do **not** rebuild the app.

You need: the tablet with the **developer build** of Percipere (built with `PERCIPERE_DEV=true`,
see the build command at the end), the MacBook running the dashboard (MAMP), and a phone that can
make a hotspot.

## 1. Find the MacBook's IP address
- **System Settings → Network → Wi-Fi → Details… → TCP/IP**: "IP address" (for example
  `172.20.10.2`), or
- open **Terminal** and type: `ipconfig getifaddr en0`

Write it down. It changes when you join another Wi-Fi, so check it again at the defense venue.

## 2. Put both devices on the same hotspot
1. Turn on the hotspot on a phone.
2. Join the **MacBook** to that hotspot.
3. Join the **tablet** to the same hotspot.
4. Start **MAMP** (both Apache and MySQL must be green) and check the dashboard opens in the
   MacBook's browser.
5. On the tablet's browser, open `http://<MacBook IP>/<dashboard folder>/api/v1/health`. You should
   see `{"status":"ok", ...}`. If you do, the app will work too.

## 3. Set the server address in the app
1. In the app open **Settings** (Mga Setting). In the developer build you will see
   **"Address ng server"** and **"Subukan ang koneksyon sa server"**.
2. Open **Address ng server** and type the dashboard folder address, for example
   `http://172.20.10.2/percipere_dashboard` (the folder where the dashboard's `index.php` lives;
   with or without a subfolder; do **not** add `/api/v1`). Press **I-save**. It is used at once.
3. Open **Subukan ang koneksyon sa server**. The app says the result aloud.

**Ibalik sa orihinal** (reset) goes back to the address the app was built with.

Plain `http://` is accepted only for local-network addresses (`10.x.x.x`, `172.16`–`172.31.x.x`,
`192.168.x.x`) and `localhost`. Any other address must start with `https://`.

## 4. What each message means
| The app says | Meaning | Fix |
|---|---|---|
| "Nakakonekta sa server. Handa na." | All good. | — |
| "Wala pang address ng server." | No address saved. | Do step 3. |
| "Walang network ang tablet." | The tablet is not on any Wi-Fi/hotspot. | Turn on Wi-Fi and join the hotspot. |
| "Mali ang address ng server." | The address does not lead to the dashboard (typo, wrong folder, wrong IP). | Re-check the IP (step 1) and the folder name; open the health link in the tablet's browser. |
| "Hindi maabot ang server." | The tablet is online but cannot reach that computer. | Tablet and MacBook must be on the **same** hotspot; turn off VPN; check the MacBook firewall (System Settings → Network → Firewall: allow Apache/MAMP or turn it off for the defense). |
| "Bukas ang computer pero hindi gumagana ang server." | The MacBook answers but Apache or MySQL is off or broken. | Start MAMP, make sure both lights are green; reopen the dashboard on the MacBook. |
| "Hindi pinapayagan ang http sa address na iyan." | `http://` to an address that is not on a local network. | Use the local IP or an `https://` address (the tunnel in section 5). |
| "Natagalan ang sagot ng server." | Slow or weak connection. | Move closer to the hotspot and test again. |

## 5. Backup: Cloudflare quick tunnel
If the hotspot does not work, the MacBook can publish the dashboard on the internet for a while:
1. Install once: `brew install cloudflared`.
2. With MAMP running, in Terminal: `cloudflared tunnel --url http://localhost:80`
   (use the MAMP port if it is not 80, for example `8888`).
3. It prints an address like `https://something-random.trycloudflare.com`. It changes every time
   you start it, and stops when you close Terminal.
4. In the app, set the **Address ng server** to that address plus the dashboard folder if the
   dashboard is in a subfolder (for example `https://something-random.trycloudflare.com/percipere_dashboard`).
   The tablet needs internet for this (mobile data or any Wi-Fi with internet).
5. **Subukan ang koneksyon sa server**.

## 6. Five-minute checklist before the defense
- [ ] MacBook charged; hotspot phone charged and the hotspot is **on**.
- [ ] MacBook and tablet both joined to the hotspot.
- [ ] MAMP: Apache and MySQL green; dashboard opens on the MacBook.
- [ ] MacBook IP checked again (step 1).
- [ ] Tablet browser opens `http://<IP>/<folder>/api/v1/health` and shows `"status":"ok"`.
- [ ] App: **Address ng server** saved, **Subukan ang koneksyon sa server** says "Nakakonekta sa server."
- [ ] Open **Aklatan**: it says it is connected, and the admin books appear.
- [ ] Test account ready (or guest mode) and one admin book already downloaded, in case the
      network drops. The app works offline for downloaded books and documents.
- [ ] Backup ready: `cloudflared` installed and the command from section 5 at hand.
- [ ] Screen-reader/voice volume on the tablet turned up.

## Build command (for whoever builds the app)
From the project folder (Windows, PowerShell or Git Bash), with a JDK available to Flutter:

```
flutter build apk --release --dart-define=PERCIPERE_DEV=true --dart-define=API_BASE_URL=http://<MacBook IP>/<dashboard folder>
```
`API_BASE_URL` is only the first default; the address can be changed in the app afterwards, so
a wrong or old IP here does not need a rebuild. Leave `API_BASE_URL` out if you prefer to type
it on the tablet. Do not put secrets in these values.
