# First tablet test with the real dashboard

The first time the tablet talks to your dashboard on the PC. Do the parts in order; each part
says how to know it worked and what to do if it did not. Nothing here needs the emulator.

You need: the PC and the tablet on the **same Wi-Fi**, XAMPP installed, and the dashboard folder
`C:\xampp\htdocs\website\percipere_web\percipere_dashboard`.

---

## Part A: put the new dashboard on the PC

### A1. Merge the pull request (on GitHub)
1. Open <https://github.com/batumbakla/percipere_web/pull/new/fix/webapp-api>.
2. Check that the base is **main** and the compare branch is **fix/webapp-api**, then click
   **Create pull request**. (If a pull request already exists, open it instead.)
3. Read the list of changed files. Click **Merge pull request**, then **Confirm merge**.
4. **Do not delete** the branch `claude/intelligent-bardeen-062ngh` yet. Keep `fix/webapp-api`
   until the test below passes.

> The merge is yours to do. Nothing in the app or the dashboard pushes to `main` for you.

### A2. Update the XAMPP folder
The XAMPP folder is the Git checkout, so it only needs to follow `main`. Open **Git Bash** or
**PowerShell** and run:

```bash
cd /c/xampp/htdocs/website/percipere_web
git status
```

- If `git status` lists changed files you did not mean to change, **stop and tell me**. Do not
  continue.
- `includes/config.local.php` is not tracked by Git, so it is never replaced.

Then:

```bash
git fetch origin
git switch main
git pull origin main
git log --oneline -3
```

The top line of `git log` should be the merge of `fix/webapp-api`.

### A3. Make a fresh database backup (before the dashboard opens)
Start **Apache and MySQL** in the XAMPP Control Panel (you do this; the tools never start or stop
MySQL). Then:

```bash
cd /c/xampp/htdocs/website/percipere_web/percipere_dashboard
/c/xampp/mysql/bin/mysqldump.exe -u root percipere_dashboard > backups/db-before-first-tablet-test.sql
```

The `backups/` folder is ignored by Git. The file should be several KB, not 0. (Your real
database is already at schema 12; the backup is for safety.)

### A4. Check the dashboard on the PC
1. Open `http://localhost/website/percipere_web/percipere_dashboard/check.php` in the PC's
   browser. Every row should be green. A red row says exactly what to fix (a PHP extension to
   switch on in `php.ini`, a missing folder, …).
2. Open `http://localhost/website/percipere_web/percipere_dashboard/login.php` and log in with
   your admin account.
3. Open **Library**. Add a category, then 2 or 3 books (a PDF, an EPUB, one without a cover) and
   leave them **Active**. Only active books reach the app.

### A5. Email codes for registration (test mode)
Registering in the app sends a 6-digit code by email. Without an SMTP account, use the test mode:
in `includes/config.local.php` (your file, never committed) add

```php
define('LOCAL_MAIL_DRIVER', 'log');
```

The codes are then written to `C:\xampp\apache\logs\error.log` as
`Percipere DEV mail to someone@example.com: code 123456`. Never use this on a public server.

---

## Part B: can the tablet reach the PC?

### B1. Find the PC's address
On the PC open **Command Prompt**, run `ipconfig`, and read **IPv4 Address** under your Wi-Fi
adapter, for example `192.168.1.61`. From here on this guide writes `PC` for that number.

### B2. Open the health page in the **tablet's browser**
`http://PC/website/percipere_web/percipere_dashboard/api/v1/health`

It must show something like `{"status":"ok","time":"2026-10-11T12:28:59+08:00"}`.

**Do not build or install the app until this page works.** It tests the Wi-Fi, the firewall and
Apache in one step.

### B3. If the page does not open
| What you see | Likely cause | What to do |
|---|---|---|
| The page spins, then "can't reach" / timeout | Windows Firewall blocks Apache, or the Wi-Fi network is "Public" | In an **administrator** Command Prompt run `netsh advfirewall firewall add rule name="Apache HTTP (private)" dir=in action=allow program="C:\xampp\apache\bin\httpd.exe" protocol=TCP localport=80 profile=private`. Set the PC's Wi-Fi to **Private** (Settings > Network & internet > Wi-Fi > the network > Network profile type). |
| "Connection refused" | Apache is not running | Start Apache in the XAMPP Control Panel. |
| Works on the PC with `localhost` but not on the tablet | You typed `localhost` on the tablet, or the PC's address changed | Use the number from `ipconfig`; routers can give the PC a new number after a restart. |
| Still nothing, phone data is on | The tablet is not on the PC's Wi-Fi, or the router isolates devices ("AP/client isolation") | Same Wi-Fi name on both; turn off "AP isolation" in the router or use a phone hotspot with the PC joined to it. |
| The page opens but shows a PHP error or `{"error":...}` | The dashboard itself has a problem | Open `check.php` on the PC and fix the red row. |
| `404 Not Found` on `/api/v1/health` | The dashboard is still the old version (without the REST routes) | Redo A2; `api/v1/index.php` and `api/v1/.htaccess` must exist and Apache needs `mod_rewrite` on (`check.php` tells). |

---

## Part C: build the app for the tablet

On the PC, in the app folder:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://PC/website/percipere_web/percipere_dashboard --dart-define=PERCIPERE_DEV=true
```

(Replace `PC` with the number from B1.) Copy `build\app\outputs\flutter-apk\app-release.apk` to the
tablet and install it yourself.

What the flags do:
- `API_BASE_URL` is the dashboard folder (no `/api/v1` at the end).
- The release APK allows plain `http://` **only to that PC address**, and to nothing else. To
  allow one more PC address, add `--dart-define=API_CLEARTEXT_HOSTS=192.168.1.70`. Every other
  host needs `https://`. The app enforces the same rule itself, because Android's setting does
  not cover every part of the app.
- `PERCIPERE_DEV=true` shows the hidden developer rows in Settings (see Part E). Leave it out for
  a build you give to testers.

---

## Part D: what to try, in this order

### 1. Library
- [ ] Open **Aklatan**. The books you added appear under their category, with covers.
      "May mga bagong aklat sa Aklatan." is spoken the first time.
- [ ] Read a book online (not downloaded), then download one. Turn Wi-Fi off and read the
      downloaded book.
- [ ] In the dashboard, add another book. Reopen the Library: it shows as **Bago**.
- [ ] More cases: `docs/testing/library-web-checklist.md`.

### 2. Register and sign in
- [ ] Register in the app. Find the code in `C:\xampp\apache\logs\error.log` (last line with
      `DEV mail to`). Enter it digit by digit.
- [ ] The dashboard's **Users** page lists the new user as active.
- [ ] More cases: `docs/testing/server-accounts-checklist.md`.

### 3. Send a report and follow its status
- [ ] Settings > **Mag-report ng problema**: write a bug report and send it. The ticket page says
      **Naipadala**.
- [ ] Dashboard > **Feedback & Bugs**: the report is there with its `PRC-…` ticket, type, module,
      severity, device and the reporter (the account or guest).
- [ ] Settings > **Aking mga report**: the report shows **Natanggap**.
- [ ] In the dashboard, set the report to **In progress**. In the app, close and reopen
      **Aking mga report** (it asks the dashboard every time it opens): **Ginagawa**.
- [ ] Set it to **Resolved**: **Naayos na**. Archive it: **Sarado** (a closed report is not
      asked about again).
- [ ] Wi-Fi off: write a report. It says it is saved and will be sent later (**Naghihintay
      ipadala**). Wi-Fi on, open **Aking mga report**: it goes out.

---

## Part E: changing the server address without rebuilding

For when the PC gets a new address, or you want to try another server.

1. Install a build with `PERCIPERE_DEV=true`.
2. Settings > **Server address (developer)** (it is near the Percy developer rows).
3. Type the dashboard folder, for example
   `http://192.168.1.70/website/percipere_web/percipere_dashboard`, then **Save**. The Library,
   accounts and reports use it straight away. **Back to the original** returns to the address the
   app was built with.

Rules the box applies:
- It must start with `http://` or `https://`. A `/api/v1` or a final `/` is cut off for you.
- `http://` is accepted **only for hosts the build allows** (the build address's host plus
  `API_CLEARTEXT_HOSTS`). A new PC number with `http://` therefore needs either `https://` or a
  new build with `--dart-define=API_CLEARTEXT_HOSTS=<new number>`. The box tells you when this is
  the problem.
- The saved address is only used by developer builds. A normal build always uses the address it
  was built with.

---

## If something fails
| Symptom in the app | Check |
|---|---|
| Library empty, "needs internet" | B2 on the tablet's browser. Then: is at least one book **Active** and does it have a file? |
| Registration says server error | The dashboard on `main`? `…/api/v1/auth/me` in the tablet's browser must show `{"error":{"code":"unauthorized",…}}`. |
| No code arrives | A5. Open `error.log` and look for the last `DEV mail to` line. If SMTP is set, check `check.php`. |
| Reports stay **Naghihintay ipadala** | Wi-Fi, B2, then open **Aking mga report** (it retries). The reason of the last failure is kept on the phone. |
| Status never changes | The dashboard's status page must be `GET /api/v1/reports/<ticket>` (try it in the tablet's browser with the ticket); then reopen **Aking mga report**. |
| Server address box says "does not allow http://" | Part E, third rule. |
| The address worked yesterday, not today | The PC's address changed (B1). Use Part E or rebuild. |

Report what happened (the screen, what you said or touched, the words the app spoke) with a
**Mag-report ng problema** report if the app can reach the server, or tell me directly if not.
