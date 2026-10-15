# Offline voice models (built 2026-10-15)

Percipere downloads three model archives once, at first launch, and then listens for
commands and speaks **without internet** and without anything installed from Google.
This folder holds what is needed to rebuild them and to put them on the server.

| Archive (`.tar.gz`) | What | Download | Unpacked | License |
|---|---|---|---|---|
| `percipere-asr-fil-en-v1` | Command recognizer: Whisper tiny fine-tuned for Filipino/Taglish ([KarlShane11/handsfree-whisper-tiny-tl](https://huggingface.co/KarlShane11/handsfree-whisper-tiny-tl)) + Silero VAD | 33.5 MB | 44.8 MB | MIT + MIT |
| `percipere-tts-tgl-v1` | Filipino voice: Meta MMS-TTS Tagalog (VITS) | 38.4 MB | 43.4 MB | **CC-BY-NC 4.0** (non-commercial) |
| `percipere-tts-en-v1` | English voice: Piper `en_US-ljspeech-medium` (int8) + English eSpeak NG data | 14.0 MB | 20.2 MB | MIT (model), public domain (LJ Speech), GPL-3.0 (eSpeak NG data) |
| **Total** | | **85.9 MB** | **108 MB** | thesis = non-commercial: OK |

The runtime is [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Flutter package
`sherpa_onnx`, Apache-2.0). Its Android library includes eSpeak NG (GPL-3.0); fine for a
thesis prototype, to be reviewed before any public release.

## Putting them on the server

1. Copy the three `.tar.gz` files and `manifest.json` (this folder) into the dashboard's
   **`models/`** folder (XAMPP: `htdocs/percipere_dashboard/models/`), so that
   `http://<server>/percipere_dashboard/models/manifest.json` opens in a browser.
2. Optional: the dashboard route `GET /api/v1/models` returning the same JSON
   (`docs/api-contract.md`). The app asks `/api/v1/models` first and falls back to
   `models/manifest.json`, so step 1 alone is enough.
3. GitHub copy (used when the server can't be reached): create the release
   **`voice-models-v1`** on `grunclerozz/percipere_app` and attach the three archives.
   The app has the same list built in (`OfflineModelCatalog.builtIn`).

The app checks every file's size and SHA-256 before unpacking it, resumes an interrupted
download, and replaces a model when the manifest lists a newer `version`.

## How each model was made

Python 3.12 venv with `torch` (CPU), `onnx`, `onnxruntime`, `sherpa-onnx`, `soundfile`,
`transformers`, `openai-whisper`. Run scripts with `python -I`.

**Command recognizer**
1. Download `model.safetensors` + `config.json` of `KarlShane11/handsfree-whisper-tiny-tl`
   (`pget.sh` downloads big files in parallel ranges when Hugging Face is slow).
2. `hf_to_openai.py <hf_dir> tiny-tl.pt` — converts the checkpoint to openai-whisper format.
3. `export_ft.py <sherpa-onnx>/scripts/whisper/export-onnx.py tiny-tl.pt tinytl <out>` —
   sherpa-onnx's own export (int8 MatMul weights).
4. `compress_emb.py tinytl-decoder.int8.onnx decoder.onnx int8` — the 80 MB token
   embedding stored as int8 per row (expanded when loaded): 90 → 30 MB, same accuracy.
5. Archive `encoder.onnx` (= `tinytl-encoder.int8.onnx`), `decoder.onnx`, `tokens.txt`
   (= `tinytl-tokens.txt`), `silero_vad.onnx` (sherpa-onnx release `asr-models`), `NOTICE.txt`.

> **Line endings:** on Windows the export writes `tokens.txt` with CRLF, which the native
> reader on Android rejects **by ending the app**. Convert them with `dos2unix tokens.txt`
> before archiving (the app also removes carriage returns from `tokens.txt` when it unpacks, and a model
> that ends the app twice while loading is marked broken instead of crashing it again).

**Filipino voice**
1. Download `models/tgl/{G_100000.pth,config.json,vocab.txt}` from `facebook/mms-tts`
   and clone `https://huggingface.co/spaces/mms-meta/MMS`.
2. `export_mms.py <tgl_dir> <MMS repo> <out> tgl` (the `stub/` folder stands in for the
   training-only `monotonic_align` extension).
3. `weights_only.py model.fp32.onnx model.onnx int8 dec` — decoder convolutions int8 per
   channel, everything else float16 (114 → 43 MB). Plain int8 dynamic quantization was
   5× slower; this keeps fp32 speed, and the output is near-identical to fp32.

**English voice** — `vits-piper-en_US-ljspeech-medium-int8` from the sherpa-onnx release
`tts-models`, renamed to `model.onnx`, with `espeak-ng-data` reduced to English
(`en_dict`, `phon*`, `intonations`, `lang/gmw`, `voices`): 18 → 1 MB.

## Why these (decision log 2026-10-15)

Measured on this PC (scripts here; `fleurs_eval.py` uses 59 real Filipino recordings of the
Google FLEURS test split, `whisper_eval.py` synthetic commands):

| Option | Size | Filipino |
|---|---|---|
| sherpa-onnx keyword spotting (phone-based zh-en, our Filipino spelling rules) | 9 MB | 2 % of Filipino words found in real speech — rejected |
| Whisper tiny (stock) | 103 MB (43 compressed) | 97 % word errors — rejected |
| Whisper base (stock) | 160 MB | 64 % word errors |
| **Whisper tiny, Filipino fine-tune** | **43 MB** | **45 % word errors**, transcripts close to the words — chosen |
| Whisper base, Filipino fine-tune (`arun100/whisper-base-tl-1`, Apache-2.0) | 80 MB | 37 % word errors, 2–3× slower |

The command matcher (fuzzy, "Ito ba ang ibig mong sabihin…?") turns near-misses into the
right command. If tablet tests show too many misses, the base fine-tune can replace the tiny
one **on the server only**: same file names, new `version` in `manifest.json`; no app change.

`test/core/offline_voice/real_models_test.dart` runs the real engines with the archives
(set `PERCIPERE_MODELS` to the folder with the archives and, on Windows, `SHERPA_DLL_DIR`
to `…/Pub/Cache/hosted/pub.dev/sherpa_onnx_windows-<version>/windows`).
