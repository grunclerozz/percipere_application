"""Runs sherpa-onnx's Whisper export on a converted fine-tune.
usage: python -I export_ft.py <sherpa_whisper_export.py> <model.pt> <name> <out_dir>
(the export writes <name>-encoder/decoder(.int8).onnx and <name>-tokens.txt in out_dir)"""
import importlib.util, os, sys
script, pt, name, out = sys.argv[1:5]
pt = os.path.abspath(pt)
os.makedirs(out, exist_ok=True); os.chdir(out)
spec = importlib.util.spec_from_file_location("exp", script); exp = importlib.util.module_from_spec(spec); spec.loader.exec_module(exp)
import whisper
exp.load_model = lambda n: whisper.load_model(pt)
class A: model = name
exp.get_args = lambda: A()
import torch
_export = torch.onnx.export
torch.onnx.export = lambda *a, **k: _export(*a, **{**k, "dynamo": False})
torch.set_num_threads(4)
from whisper.model import disable_sdpa
with disable_sdpa():
    exp.main()
