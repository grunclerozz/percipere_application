"""WER of a sherpa-onnx Whisper model on real Filipino speech (FLEURS dev subset).
usage: python -I fleurs_eval.py enc dec tokens lang fleurs_dir"""
import sys, os, glob, re
import numpy as np, sherpa_onnx, soundfile as sf
sys.stdout.reconfigure(encoding="utf-8")
enc, dec, tok, lang, d = sys.argv[1:6]
rec = sherpa_onnx.OfflineRecognizer.from_whisper(encoder=enc, decoder=dec, tokens=tok, language=lang, task="transcribe", num_threads=4)
ref = {}
for line in open(os.path.join(d, "dev.tsv"), encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) > 3: ref[parts[1]] = parts[3]
def words(s): return re.sub(r"[^a-zñ0-9 ]", " ", s.lower().replace("-", " ")).split()
def ed(a, b):
    dp = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        prev, dp[0] = dp[0], i
        for j in range(1, len(b) + 1):
            cur = dp[j]; dp[j] = min(dp[j] + 1, dp[j-1] + 1, prev + (a[i-1] != b[j-1])); prev = cur
    return dp[-1]
errs = n = 0; shown = 0
for f in sorted(glob.glob(os.path.join(d, "x", "**", "*.wav"), recursive=True)):
    name = os.path.basename(f)
    if name not in ref: continue
    x, sr = sf.read(f, dtype="float32")
    s = rec.create_stream(); s.accept_waveform(sr, x); rec.decode_stream(s)
    h, r = words(s.result.text), words(ref[name]); errs += ed(r, h); n += len(r)
    if shown < 4: print("REF:", " ".join(r)); print("HYP:", " ".join(h)); shown += 1
print(f"{os.path.basename(enc)} lang={lang}: WER {100*errs/n:.1f}% over {n} words")
