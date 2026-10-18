# Aklatan with the real dashboard: tablet checklist

Builds on `docs/testing/phase-6e-checklist.md` (the Library itself). This one is about books
coming from the dashboard (Library page) instead of the old sample books.

## Setup
(The first time, follow `docs/testing/first-tablet-test.md` first: merge, health check, build.)

1. On the PC: Apache and MySQL running; open the dashboard > **Library**. Add a category, then
   a few books (a PDF, an EPUB with a cover, one with no cover) and leave them **Active**.
   The dashboard's `docs/api-contract.md` explains how to find the PC's address (`ipconfig`)
   and allow Apache through the firewall.
2. Build with the dashboard's address:
   `flutter build apk --release --dart-define=API_BASE_URL=http://<PC LAN IP>/website/percipere_dashboard`
3. Phone/tablet and PC on the same Wi-Fi.

## Checks
- [ ] **Open the Library** with Wi-Fi on: the dashboard's books appear under their category, with
      covers; "May mga bagong aklat sa Aklatan." is spoken the first time.
- [ ] A book with no cover shows the plain placeholder and nothing breaks.
- [ ] **Read online** (not downloaded): progress is announced, the book opens in the Reader.
- [ ] **Download:** progress and completion announced; the book reads with Wi-Fi off afterwards.
- [ ] **Language:** a Filipino book reads with the Filipino voice, an English one with English.
- [ ] **New book:** add another book in the dashboard, close and reopen the Library: it appears as
      "Bago".
- [ ] **Update:** in the dashboard edit a downloaded book's title or upload a new file (its version
      goes up): the app offers to update the download and keeps the reading position.
- [ ] **Deactivate** a book in the dashboard: after reopening the Library the app tells you it was removed; if
      it was downloaded, the progress record stays and the book is marked unavailable.
- [ ] **Wi-Fi off, Library open:** the last list stays; not-downloaded books say they need internet.
- [ ] **PC off or wrong address:** the Library does not crash; it behaves as offline.
- [ ] **Interrupted download** (turn Wi-Fi off halfway): the book is not left half-downloaded; try
      again with Wi-Fi on.
- [ ] A build **without** `API_BASE_URL`: your own documents work, the admin shelves are empty, and
      nothing crashes.
- [ ] Spam: open and close the Library quickly; no crash, no duplicate books.
