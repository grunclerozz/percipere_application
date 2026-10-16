# Percipere Android App – Finish TODAY (read me first)

Android app folder: D:\Development\Flutter Projects\percipere_app
Put these files in:  D:\Development\Flutter Projects\percipere_app\docs\prompts\
(The dashboard prompts are in the "dashboard-later" folder for the other person.)

## Order for today

| Step | File | Task | Model | Chat |
|---|---|---|---|---|
| 1 | a1-merge.md | Merge finished branches into main | Sonnet 5.5 | New chat |
| 2 | a2-voice-fix.md | "Say it twice" / "hold twice" / false "not available" + low-risk noise fix | Opus 5.5 | New chat |
| – | (you) | Build APK, test voice on the tablet | – | – |
| 3 | a3-algorithms.md | 4 main algorithms + thesis write-up | Sonnet 5.5 | New chat |
| 4 | a4-connection.md | Server address setting + test connection (for MacBook at defense) | Sonnet 5.5 | New chat |
| 5 | a5-final-check.md | Analyze, tests, release build, defense checklist + demo script | Sonnet 5.5 | New chat |
| later | a6-percy-official-eval.md | Official Percy evaluation (when team test phrases are done) | Sonnet 5.5 | New chat |

Tiny fixes (a label, a typo, a color): Haiku 5.5, new chat.

## How to start each step

    cd "D:\Development\Flutter Projects\percipere_app"
    git status            # must say "nothing to commit"
    claude --model sonnet "Read docs/prompts/a1-merge.md and do it."

Use --model opus for step 2. (--model opus = Opus 5.5, sonnet = Sonnet 5.5, haiku = Haiku 5.5;
full IDs: claude-opus-5-5, claude-sonnet-5-5, claude-haiku-5-5.)

## Rules for today

- NEW chat for every step. After the step commits: /exit.
- Same chat only to answer its questions within the hour.
- Each step after step 1 creates its own branch from main and merges back into main
  itself at the end (after analyze + tests pass), so the next step starts from the latest.
- After each step: git status, and build/test if it changed behavior.
- If a change breaks something and time is short: git revert <commit> instead of debugging.
- If you hit your usage limit, run the remaining steps on Sonnet.
- Don't run two Claude sessions in this folder at the same time.

Dropped for now (say "future work" at the defense): ElevenLabs voice, switching the vision
AI provider, heavy noise-cancellation models. Percy uses the free offline voice everywhere.
