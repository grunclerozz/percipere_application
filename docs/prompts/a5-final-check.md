# A5 – Final check + defense prep (Sonnet 5.5, new chat, on main)

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/05-current-status.md and the latest
worklog. Work on main. Fix only real failures; ask before anything larger.

1. Run flutter analyze, the tests for everything changed today (voice, Percy, algorithms,
   connection, settings, accessibility), and a release build (flutter build apk --release).
   Skip the full 1.5-hour suite. Report: Passed, Fixed during the check, Known issues
   (with severity).
2. Check there are no secrets in the repo (API keys, passwords, personal data).
3. Make sure these docs are current: docs/thesis/algorithms.md, docs/connection-guide-app.md,
   docs/handoff/*, docs/testing/system-test-checklist.md.
4. Write docs/defense-checklist.md:
   - Night before: charge tablet, install the release APK, earphones with mic.
   - 1 hour before: start MAMP on the MacBook, connect tablet + MacBook to the hotspot,
     set Server address, Test connection, open Aklatan, test one voice command.
   - If the server fails: Cloudflare quick tunnel backup, then the offline demo path
     (scan/upload + read aloud, gestures, Percy, downloaded books, Maglarawan offline).
   - Backup: APK on a flash drive, screen recordings of each feature.
5. Write docs/demo-script.md: a 10-minute demo in order (who speaks, what to say/do, which
   feature, which algorithm to mention), ending with evaluation results if available.
6. Manual tablet test list (short): quiet + noisy voice test, hold while Percy talks,
   airplane mode, reader, Maglarawan online/offline, Aklatan download, report an issue,
   server switch.
Update status + worklog, commit on main (don't push).
