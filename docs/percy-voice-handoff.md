# Percy's voice: how to make the clips (for a teammate, step by step)

**Who this is for:** a teammate who is not a programmer. Follow the steps in order, in
**PowerShell**. You will make Percy's spoken lines with the ElevenLabs voice, and put them in the
project so the app can play them offline. The app already works without them (it uses the phone's
voice); the clips only make Percy sound like our chosen voice.

**Never share the ElevenLabs key.** Not in chat, not in a file, not in a screenshot, not in a
commit. If you think it leaked, delete it in ElevenLabs and make a new one.

## What you need first
| Need | How to check |
|---|---|
| A **paid** ElevenLabs plan (Starter or higher). The free plan blocks this voice and gets `detected_unusual_activity` or `payment_required`. | ElevenLabs website → your profile → Subscription |
| The voice **u0P5zPuh3SvxTi9vSTCn** in **your** "My Voices" (open the voice in the Voice Library and press "Add to My Voices"). | ElevenLabs → Voices → My Voices |
| Your API key (ElevenLabs → profile → API Keys → Create). Keep it private; you will type it in step 4. | – |
| **Python** through the `py` command. | `py --version` should print `Python 3...` |
| Access to the GitHub repo and **Git** installed. | `git --version` |
| About **24,000 characters** of quota (the dry run in step 3 tells the exact number). | ElevenLabs → Subscription shows what is left |

## Steps
Open PowerShell. Use the same window for all steps (the key lives only in this window).

**1. Go to the project and get the newest files**
```powershell
cd "D:\Development\Flutter Projects\percipere_app"
git checkout main
git pull
```
(If your project is in another folder, use that folder in the first line. If `git pull` says you
have changes, stop and ask the team before going on.)

**2. Make a branch for the clips**
```powershell
git checkout -b feat/percy-voice-clips
```

**3. Dry run: see what would be made (no key, no cost)**
```powershell
py tool\percy_voice\generate_percy_voice.py --dry-run
```
It prints how many lines and characters (about 590 lines, 24,000 characters). Make sure your
ElevenLabs quota is at least that.

**4. Type the key (it is not saved anywhere)**
```powershell
$env:ELEVENLABS_API_KEY = Read-Host "ElevenLabs API key"
```
Paste the key and press Enter. Nothing is shown while you paste; that is normal.

**5. Try 3 clips first and listen**
```powershell
py tool\percy_voice\generate_percy_voice.py --limit 3
```
Open the folder `assets\percy\voice` and play the 3 `.mp3` files. They should be Percy's voice,
clear, in Filipino or English. If the voice is wrong, stop and tell the team (do not run step 6).

**6. Make all the clips** (takes several minutes; it can be stopped and run again, it skips finished clips)
```powershell
py tool\percy_voice\generate_percy_voice.py
```

**7. Remove the key from this window**
```powershell
Remove-Item Env:\ELEVENLABS_API_KEY
```

**8. Check that everything is there (no key needed)**
```powershell
py tool\percy_voice\generate_percy_voice.py --check
```
It should say `590 of 590 lines have clips` (the number can differ if the lines changed) and
`All lines have clips.` If it says some are missing, do steps 4, 6 and 7 again.

**9. Save the clips in Git and send them**
```powershell
git add assets/percy/voice
git status
git commit -m "Percy: ElevenLabs voice clips"
git push -u origin feat/percy-voice-clips
```
`git status` must show only files inside `assets/percy/voice`. If it shows other files, do not
commit; ask the team. Then tell the team the branch name. **Do not push to `main`.**

## When something goes wrong
| What you see | What it means | What to do |
|---|---|---|
| `HTTP 401` / `invalid_api_key` | The key is wrong, has a space, or was deleted. | Do step 4 again with a freshly copied key. |
| `detected_unusual_activity` | ElevenLabs blocked the free plan or a VPN/proxy. | Use a paid plan, turn off VPN, wait and try again. |
| `quota_exceeded` / "not enough credits" | The plan has fewer characters than needed. | Check Subscription, buy more characters or wait for the monthly reset, then run step 6 again (it continues where it stopped). |
| `voice_not_found` | The voice is not in **your** My Voices. | Add voice `u0P5zPuh3SvxTi9vSTCn` to My Voices (see "What you need first"), then retry. |
| `payment_required` | The plan does not allow this voice or use. | Upgrade to a paid plan; check that the last payment went through. |
| `network error` or `HTTP 429/500/502/503` repeating | Internet problem or ElevenLabs is busy. The script already retries 5 times. | Check the connection and run step 6 again. |
| `ELEVENLABS_API_KEY is not set` | You are in a new window or skipped step 4. | Do step 4 in this window. |
| `py` is not recognized | Python is not installed or not on PATH. | Install Python 3 from python.org (tick "Add python.exe to PATH" and "py launcher"), reopen PowerShell. |
| `git pull` says there are local changes | You changed files in the project. | Stop and ask the team. |
| `--check` says clips are missing after step 6 | The run was stopped by an error above. | Fix the error, then do steps 4, 6, 7, 8 again. |

## For the team (not for her)
- The app needs no change: it uses the clips automatically when `assets/percy/voice/manifest.json`
  lists them. Settings → Percy → "Boses ni Percy" shows "N sa M na linya ang may clip".
- After merging, build and install on the tablet and listen to Percy; native mp3 playback has not been
  tested on a device yet (`docs/handoff/03-voice-and-percy.md`).
- Details of the script: `tool/percy_voice/README.md`.
