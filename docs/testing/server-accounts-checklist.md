# Accounts on the web app: tablet checklist (2026-10-10)

The app logs in against the PHP dashboard
(`C:\xampp\htdocs\website\percipere_web\percipere_dashboard`, endpoints in its `docs/API.md`).

## Before testing (PC)

1. **Turn on XAMPP:** Apache and MySQL.
2. **Edit the dashboard's `includes/config.local.php`:**
   - Set `LOCAL_DB_NAME` to `'percipere_dashboard_dev'`.
   - Add `define('LOCAL_MAIL_DRIVER', 'log');`. Codes then appear in `C:\xampp\apache\logs\error.log` as `Percipere DEV mail to …: code 123456`.
   - With real SMTP settings, leave the mail driver out instead.
3. **Check the tablet can reach the PC.** Same Wi-Fi as the PC (PC address `192.168.1.61`; check with `ipconfig` if it changed).
   - In the tablet's browser, open `http://192.168.1.61/website/percipere_web/percipere_dashboard/api/v1/auth/me`. You should see `{"error":{"code":"unauthorized",…}}` (the dashboard must be the version with the REST routes).
   - If it doesn't load: Windows Firewall → allow "Apache HTTP Server" on **Private** networks too (today it is allowed on Public only).
4. **Build the app pointed at the PC.** An `http://` address also turns on plain HTTP, but only for that PC's address (other hosts: `--dart-define=API_CLEARTEXT_HOSTS=...`). The full walk-through is `docs/testing/first-tablet-test.md`.

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.61/website/percipere_web/percipere_dashboard
```

Without `API_BASE_URL` the app keeps accounts on the phone only, as before.

## Register
- [ ] Register (voice or typing) → the app says "Nagpadala kami ng 6 na numerong code sa …".
- [ ] Say the code digit by digit ("dalawa apat anim…" or "2 4 6…"). The app reads it back as single digits.
- [ ] A wrong code → "Mali o luma na ang code. Subukan ulit."
- [ ] "ipadala ulit" → "Nagpadala kami ng bagong code." (A second request within 60 s is refused, and the app says how long to wait.)
- [ ] The right code → "Nagawa na ang iyong account, …" → the setup (fingerprint offer first, if the tablet has one). There is no security question.
- [ ] Dashboard → Users: the new user is listed as **active**.
- [ ] Registering again with the same email → "May account na ang email na iyan…".

## Login
- [ ] Wrong password → "Mali ang email o password. … pang subok". After 5 wrong tries, a countdown.
- [ ] Right password → "Maligayang pagbabalik, …", and you land where the account left off.
- [ ] Dashboard → Users → **Suspend** the user, then log in → "Naka-suspend ang account na ito…".
- [ ] While logged in, Suspend the user in the dashboard, then switch to another app and back → "Naka-suspend ang iyong account, kaya na-log out ka…" → Welcome.
- [ ] Reactivate the user → login works again.
- [ ] Wi-Fi off, the same account → "Walang internet, kaya ang naka-save sa tablet na ito ang ginamit." → logged in.
- [ ] Wi-Fi off, an account never used on this tablet → "Kailangan ng internet sa unang pag-login…".
- [ ] An account made before this update (only on the tablet) → login → "Inililipat namin sa server ang iyong account…" → code → logged in with all its settings and Library.

## Forgot password
- [ ] Login → "nakalimutan" → email → "Kung may account ang …, nagpadala na kami ng code…".
- [ ] Code + new password → "Napalitan na ang password, at naka-login ka na."
- [ ] The old password no longer works on the server. (Another tablet logged in to that account stays logged in, but its server token stops working; it must log in with the new password next time.)

## Logout
- [ ] Settings → Log out works at once, also offline. (On the server, that device's token stops working.)

## Everything else unchanged
- [ ] Guest mode ("Subukan muna"), fingerprint login, the Library and Maglarawan work as before.
