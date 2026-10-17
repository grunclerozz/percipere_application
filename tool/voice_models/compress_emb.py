"""Stores large float32 initializers that dynamic quantization left alone (Whisper's
token embedding) as int8 per-row + DequantizeLinear, or fp16 + Cast. ORT expands them
once at load. usage: python -I compress_emb.py in.onnx out.onnx int8|fp16 [min_mb]"""
import os, sys
import numpy as np, onnx
from onnx import helper, numpy_helper, TensorProto
src, dst, mode = sys.argv[1:4]
min_bytes = float(sys.argv[4] if len(sys.argv) > 4 else 4) * 1024 * 1024
m = onnx.load(src); g = m.graph; new_nodes = []
for t in list(g.initializer):
    if t.data_type != TensorProto.FLOAT: continue
    w = numpy_helper.to_array(t)
    if w.nbytes < min_bytes or w.ndim != 2: continue
    name = t.name; g.initializer.remove(t)
    if mode == "fp16":
        g.initializer.append(numpy_helper.from_array(w.astype(np.float16), name + "_h"))
        new_nodes.append(helper.make_node("Cast", [name + "_h"], [name], to=TensorProto.FLOAT))
    else:
        scale = (np.abs(w).max(axis=1) / 127.0).astype(np.float32); scale[scale == 0] = 1e-8
        q = np.clip(np.round(w / scale[:, None]), -127, 127).astype(np.int8)
        g.initializer.extend([numpy_helper.from_array(q, name + "_q"), numpy_helper.from_array(scale, name + "_s"),
                              numpy_helper.from_array(np.zeros_like(scale, dtype=np.int8), name + "_z")])
        new_nodes.append(helper.make_node("DequantizeLinear", [name + "_q", name + "_s", name + "_z"], [name], axis=0))
    print("compressed", name, w.shape)
for n in reversed(new_nodes): g.node.insert(0, n)
onnx.save(m, dst); print(os.path.getsize(src), "->", os.path.getsize(dst))
