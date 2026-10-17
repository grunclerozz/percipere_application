# Percy's bundled voice (ElevenLabs)

Percy's **fixed** sentences are generated once with ElevenLabs and bundled in the app
(`assets/percy/voice/`, mp3, mono, 22.05 kHz, 32 kbps). The app has **no API key** and needs
no server: it plays the clip whose hash matches the sentence, and speaks everything else
(book titles, numbers, any sentence without a clip) with the offline voice.

Voice id (not a secret): `u0P5zPuh3SvxTi9vSTCn`. Default model `eleven_multilingual_v2`
(supports Filipino). Needs only Python 3 (no packages).

## Run it (PowerShell, from the repo root)
```powershell
cd "D:\Development\Flutter Projects\percipere_app"

# 1. See what would be generated (no key, no API call)
python tool\percy_voice\generate_percy_voice.py --dry-run

# 2. Set the key for THIS window only (never saved to a file)
$env:ELEVENLABS_API_KEY = Read-Host "ElevenLabs API key"

# 3. Try 3 clips first, listen to assets\percy\voice\*.mp3
python tool\percy_voice\generate_percy_voice.py --limit 3

# 4. Generate the rest (already generated clips are skipped)
python tool\percy_voice\generate_percy_voice.py

# 5. Forget the key
Remove-Item Env:\ELEVENLABS_API_KEY
```
It prints the characters used. Then commit `assets/percy/voice/` (the audio IS committed).

Options: `--model eleven_v3` (sends `language_code` too), `--prune` (delete clips of sentences
that no longer exist), `--dry-run`, `--limit N`.

## What it reads
- `assets/percy/responses.json` (intents, dialogue) and the greeting in `assets/percy/persona.json`.
- ARB keys listed in `tool/percy_voice/extra_arb_keys.json` (tutorial lines, mic/unavailable messages).
- Lines are cut into **sentences** (the app speaks one sentence at a time). Sentences with
  `{placeholders}` are skipped on purpose (offline voice).

## Re-running
Change a line in `responses.json` -> run the script again: only new sentences are generated.
Changing `--model` regenerates everything. Re-run `--prune` to remove clips nobody uses.

## Manifest and hash
`assets/percy/voice/manifest.json`: `clips[<hash>] = {file, lang, text, voice_id, model, date}`.
Hash = first 16 hex of `sha256("<lang>|<text>")`, text trimmed with whitespace runs collapsed;
`lang` is `fil` or `en`. The same rule is in `lib/core/percy/percy_clips.dart`
(a test checks both give the same hash).

## Safety
The key is read only from `ELEVENLABS_API_KEY`; never written to a file, log or output.
`.env` files are git-ignored. Never paste the key into chat, code or docs.
