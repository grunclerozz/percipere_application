"""Command accuracy of a sherpa-onnx Whisper model on synthesized commands.
usage: python -I whisper_eval.py <enc> <dec> <tokens> <lang> <phrases.txt> <tgl_dir> <en_dir> [-v]"""
import sys, time, re, difflib
import numpy as np, sherpa_onnx
sys.stdout.reconfigure(encoding="utf-8")
enc, dec, tok, lang, pf, tgl, en = sys.argv[1:8]
rec = sherpa_onnx.OfflineRecognizer.from_whisper(encoder=enc, decoder=dec, tokens=tok, language=lang, task="transcribe", num_threads=4)
phrases = [p for p in open(pf, encoding="utf-8").read().split("\n") if p]
def tts(d, data=""):
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=d+"/model.onnx", tokens=d+"/tokens.txt", data_dir=data), num_threads=4)))
fil, eng = tts(tgl), tts(en, en + "/espeak-ng-data")
english = set(w.split()[0].lower() for w in open(sys.argv[8], encoding="utf-8")) if len(sys.argv) > 8 and not sys.argv[8].startswith("-") else set()
def norm(s): return re.sub(r"[^a-zñ ]", " ", s.lower().replace("-", " ")).split()
def best(text):
    t = " ".join(norm(text)); scores = []
    for p in phrases:
        q = " ".join(norm(p)); r = difflib.SequenceMatcher(None, t, q).ratio()
        if q and (f" {q} " in f" {t} "): r = max(r, 0.9 + 0.01 * len(q))
        scores.append((r, p))
    scores.sort(reverse=True); return scores[0]
rng = np.random.default_rng(2)
ok = n = 0; times = []; bad = []
for p in phrases:
    voices = [("fil", fil, 0.95), ("fil", fil, 1.15)]
    if english and all(w in english for w in norm(p)): voices.append(("en", eng, 1.0))
    for name, v, sp in voices:
        a = v.generate(p, sid=0, speed=sp); x = np.asarray(a.samples, np.float32)
        if a.sample_rate != 16000: x = np.interp(np.linspace(0, len(x)-1, int(len(x)*16000/a.sample_rate)), np.arange(len(x)), x).astype(np.float32)
        pad = int(16000 * float(__import__("os").environ.get("PAD", "0.25"))); x = np.concatenate([np.zeros(pad, np.float32), x, np.zeros(pad, np.float32)]); x = x + (rng.standard_normal(len(x)) * 0.003).astype(np.float32)
        s = rec.create_stream(); s.accept_waveform(16000, x)
        t = time.time(); rec.decode_stream(s); times.append(time.time() - t)
        txt = s.result.text; score, got = best(txt); n += 1
        if got == p and score >= 0.6: ok += 1
        else: bad.append(f"{name}{sp} '{p}' heard '{txt.strip()}' -> '{got}' {score:.2f}")
print(f"{enc.split('/')[-1]} lang={lang or 'auto'}: commands right {ok}/{n} ({100*ok/n:.0f}%), decode {np.mean(times):.2f}s avg")
if "-v" in sys.argv: print("\n".join(bad))
