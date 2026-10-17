"""Exports an MMS-TTS VITS checkpoint to ONNX for sherpa-onnx.

Follows https://k2-fsa.github.io/sherpa/onnx/tts/mms.html.
usage: python -I export_mms.py <model_dir with G_100000.pth config.json vocab.txt> <mms repo> <out_dir> <lang>
"""
import collections
import os
import sys

model_dir, mms_repo, out_dir, lang = sys.argv[1:5]
here = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [os.path.join(here, "stub"), mms_repo, os.path.join(mms_repo, "vits")]

import onnx  # noqa: E402
import torch  # noqa: E402
from vits import utils  # noqa: E402
from vits.models import SynthesizerTrn  # noqa: E402


class OnnxModel(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, x, x_lengths, noise_scale=0.667, length_scale=1.0, noise_scale_w=0.8):
        return self.model.infer(x=x, x_lengths=x_lengths, noise_scale=noise_scale,
                                length_scale=length_scale, noise_scale_w=noise_scale_w)[0]


def main():
    os.makedirs(out_dir, exist_ok=True)
    hps = utils.get_hparams_from_file(os.path.join(model_dir, "config.json"))
    assert hps.data.training_files.split(".")[-1] != "uroman"
    with open(os.path.join(model_dir, "vocab.txt"), encoding="utf-8") as f:
        symbols = [line.replace("\n", "") for line in f]
    upper = [s.upper() for s in symbols]
    dupes = {t for t, c in collections.Counter(upper).items() if c > 1}
    with open(os.path.join(out_dir, "tokens.txt"), "w", encoding="utf-8", newline=chr(10)) as f:
        for idx, tok in enumerate(symbols):
            f.write(f"{tok} {idx}\n")
            if tok.lower() != tok.upper() and len(tok.upper()) == 1 and tok.upper() not in dupes:
                f.write(f"{tok.upper()} {idx}\n")
    net_g = SynthesizerTrn(len(symbols), hps.data.filter_length // 2 + 1,
                           hps.train.segment_size // hps.data.hop_length, **hps.model)
    net_g.cpu().eval()
    utils.load_checkpoint(os.path.join(model_dir, "G_100000.pth"), net_g, None)
    model = OnnxModel(net_g)
    x = torch.randint(low=1, high=10, size=(1, 50), dtype=torch.int64)
    x_length = torch.tensor([x.shape[1]], dtype=torch.int64)
    scales = [torch.tensor([1], dtype=torch.float32) for _ in range(3)]
    filename = os.path.join(out_dir, "model.fp32.onnx")
    torch.onnx.export(model, (x, x_length, *scales), filename, opset_version=13, dynamo=False,
                      input_names=["x", "x_length", "noise_scale", "length_scale", "noise_scale_w"],
                      output_names=["y"],
                      dynamic_axes={"x": {0: "N", 1: "L"}, "x_length": {0: "N"}, "y": {0: "N", 2: "L"}})
    m = onnx.load(filename)
    for k, v in {"model_type": "vits", "comment": "mms", "url": "https://huggingface.co/facebook/mms-tts/tree/main",
                 "add_blank": int(hps.data.add_blank), "language": lang, "frontend": "characters",
                 "n_speakers": int(hps.data.n_speakers), "sample_rate": hps.data.sampling_rate}.items():
        e = m.metadata_props.add()
        e.key, e.value = k, str(v)
    onnx.save(m, filename)
    print("exported", filename, os.path.getsize(filename))


with torch.no_grad():
    main()
