# A4 – App connection for the defense (Sonnet 5.5, new chat)
# Optional: let it READ the dashboard's API code:
# claude --model sonnet --add-dir "C:\xampp\htdocs\website\percipere_web\percipere_dashboard" "Read docs/prompts/a4-connection.md and do it."

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/05-current-status.md, 04-api-and-dashboard.md
and the latest worklog. Create branch chore/app-connection from main. SCOPE rule applies.
Don't run the app on my device. Analyze + relevant tests only. You may READ the dashboard
folder but don't edit it (another person will handle the dashboard).

CONTEXT: we have no hosting. At the defense the dashboard will run on a MacBook (MAMP),
with the tablet and MacBook on the same phone hotspot; a free Cloudflare quick tunnel
(https://….trycloudflare.com) from the MacBook is the backup. Our professor says the same
API works anywhere: only the server ADDRESS changes. The app must switch servers WITHOUT
rebuilding.

1. API base URL: default from --dart-define=API_BASE_URL; plus a "Server address" setting in
   the hidden developer settings (validated, saved, applied immediately, works with or
   without a subfolder path) and a "Test connection" button that calls the health endpoint
   (/api/v1/health) and speaks the result: OK + server version, or the exact reason (no
   network, wrong address, server down, HTTP blocked, timeout).
2. Network security: HTTPS always allowed; cleartext HTTP allowed in release builds ONLY for
   private-network addresses (10.x, 172.16–31.x, 192.168.x) and localhost.
3. Check every API call (auth, books list/files/covers, downloads, reports, models manifest)
   uses the base URL, with timeouts and clear spoken offline messages. List any endpoint the
   dashboard seems to lack (don't change the dashboard).
4. Optional, small: when the Aklatan opens, briefly say whether it's connected to the server.
5. Write docs/connection-guide-app.md for non-technical students:
   - How to find the MacBook's IP (System Settings > Network, or `ipconfig getifaddr en0`)
   - Join tablet + MacBook to the same hotspot; set Server address; Test connection
   - What each error means and how to fix it
   - Backup: Cloudflare quick tunnel URL
   - 5-minute pre-defense checklist
FINISH: analyze + tests; if all pass, merge into main. Update docs/handoff (04, 05, worklog),
commit (don't push), list changed files, and give me the exact build command.
