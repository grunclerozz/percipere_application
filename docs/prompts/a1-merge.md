# A1 – Merge finished work into main (Sonnet 5.5, new chat)

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/05-current-status.md and the latest
worklog entries. SCOPE rule: touch only what this task needs. Don't run the app on my
device. Run flutter analyze and only the relevant tests (not the full suite, not the
release build).

TIME IS SHORT (defense is in 3 days, we finish today). Don't wait for my OK unless needed.

1. List all local branches with their last commit, whether merged into main, and status
   from the worklog (finished / unfinished). Known: feat/percy-smarter (finished,
   provisional model), feat/voice-hold-interrupt (finished), docs/database-masterlist-v2
   (docs only).
2. Merge every FINISHED branch into main in a sensible order, resolving conflicts so every
   feature keeps working. STOP and ask only if a branch is unfinished or a conflict is risky.
3. Run flutter analyze and the tests for Percy, voice, settings, accessibility.
4. Update docs/handoff/05 and the worklog, commit on main (don't push). Report merged
   branches, conflicts and how you resolved them, and test results in 10 lines or less.
