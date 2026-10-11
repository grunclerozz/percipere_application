# Report an Issue (Mag-report ng problema) — Phase 10

Status: **built 2026-10-11, awaiting the user's tablet test.** Decision log: 2026-10-11.

## Entry points
- **Settings:** "Mag-report ng problema" and "Aking mga report".
- **Home:** a "Mag-report ng problema" link under Settings. The app has no Help screen; the owner chose Home as the second entry point.
- **Voice, from any screen:** "mag-report", "mag-report ng problema", "i-report", "report an issue", "report a problem", "report", "may problema", "ulat". These map to `NavIntent.report`.
  - "puna" and "feedback" are not commands, because they are answers on page 1.
- **Percy:** the `report_issue` intent, with 18 Starter rows in `data/percy/intents.csv`.
  - The model learned it in the 2026-10-11 retrain (3 of 3 test sentences right).
  - `ReportIssueRule` (a keyword rule in `lib/core/percy/percy_intent.dart`) stays as a backstop for sentences that also name another part of the app.
  - The exact short phrases above also work through the phrase matcher.

## Flow
One page at a time (`lib/features/report/report_issue_screen.dart`; page order in `report_flow.dart`). Each page speaks its question and its options when it opens.

| # | Page | Options / input |
|---|---|---|
| 1 | Uri | May sira (Bug) · Mungkahi (Feature request) · Puna (General feedback) |
| 2 | Bahagi ng app | OCR · Camera · Voice Commands · Accounts · Text-to-Speech · Gesture Pad · Aklatan (Library) · Maglarawan · Percy · Iba pa (Other) |
| 3 | Gaano kalala | **Bug only.** Low (minor annoyance) · Medium (works but wrong) · High (doesn't work) · Critical (crashes or data lost). The explanation is spoken with each option. |
| 4 | Ano ang nangyari | Say it or type it; "Magsalita" dictates again. Read back as "Narinig ko: … Tama ba?": yes keeps it, no asks again. 10–1000 characters. |
| 5 | Email | **Logged in:** pre-filled, and "Gamitin ang email na ito: …?" is asked; no lets you say or type another. **Guest:** optional, "Laktawan" skips it. The format is checked, and the page explains the email is only used to reply. |
| 6 | Repasuhin | **Read aloud:** the answers, the automatic details and the privacy line. **Options:** "Ipadala", or "Baguhin" ("Alin ang babaguhin?" jumps to that page, then back to the review). Each answer line also opens its page. |
| 7 | Ticket | The ticket number, read character by character, then type, module, severity, the description (shortened), date and time, and status. "Ulitin" repeats it; "Tapos na" goes back to where the report was opened. |

**Controls** are the same as elsewhere in the app:
- **Choosing an option:** swipe to move between options, then double-tap; or say the option's name in Filipino or English ("bug", "may sira", "kritikal").
- **Going back:** two-finger swipe right, or "bumalik", returns to the previous page. On page 1, leaving asks first if anything was answered.
- **Cancelling:** "kanselahin" asks first, then cancels the whole report.
- **On the text pages:** "susunod" goes on, and "magsalita" or a long-press dictates again.
- **Screen:** large targets, the theme's colors and text size, and TalkBack labels on every control.

## Data
**Ticket number:** `PRC-YYYYMMDD-XXXX`. XXXX is 4 random characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0, O, 1 or I). The number is unique on the phone and on the server.

**Attached automatically, and shown on the review page:** app version, Android version, phone model, the screen the report was opened from, and the date and time.

**Never attached:** document text, scanned images, book content, voice recordings, passwords, Percy logs or screenshots.

**Local table `issue_reports`** (migration **v6**; the database was already at v5 because of Percy's log). It has the spec's fields plus:
- `user_id`, so "Aking mga report" shows only that account's reports;
- `attempts` and `last_error`.

A report outlives its account (`ON DELETE SET NULL`), and a guest's reports move to the account they register.

## Sending
Every report is saved first, then sent (`IssueReportSync`).

**Where it goes:** `POST {API_BASE_URL}/api/v1/reports` (until 2026-10-11 it was `api/v1/feedback.php`, which the dashboard keeps as a deprecated alias).
- Reports appear in Feedback & Bugs, linked to the user (Bearer token).
- Body: `ticket_no`; `type`, `module`, `severity` as `{code, label}` (severity `null` unless a bug); `description`; `email`; `reporter` (`{kind: account|guest, display_name: null}`); `app_version`, `os_version`, `device_model`, `source_screen`, `created_at`.
- Reply: `201 {id, ticket_no, status: "open", linked}`. A repeated ticket gets `200` with the same id, so a retry never makes a copy.
- **Status:** "Aking mga report" asks `GET /api/v1/reports/{ticket_no}` for each sent report that is not closed (20 newest) and keeps the answer in `issue_reports.server_status` (migration v7). The row and the spoken details show Natanggap / Ginagawa / Naayos na / Sarado; a report not sent yet shows Naghihintay ipadala or Hindi naipadala. Offline keeps the last answer.

**When it is sent:**
- Right after "Ipadala".
- At app start, when the app returns to the front, and when the connection returns.
- When "Aking mga report" opens.

**Status:**
- No connection or a server error: the report stays `pending` ("Naghihintay ipadala").
- A report the server refuses (4xx other than 429): `failed`, and it stays on the phone.
- Nothing is ever deleted, and the app never talks to MySQL directly.

**Builds without `API_BASE_URL`:** there is no mock. Reports wait as pending, which is the truth, until a build with the web app sends them.

## Privacy
The email and review pages say: "Ang report at email ay gagamitin lang para ayusin ang app at sagutin ka (RA 10173)." Guests can report without an email.

## My reports
Settings → "Aking mga report" lists ticket, type, date and status, newest first, for the logged-in account (or for reports written with no account). Choosing one reads its details aloud.
