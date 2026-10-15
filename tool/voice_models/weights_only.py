"""Stores the big Conv/ConvTranspose weights compactly; they are expanded back to
float32 when the model loads, so inference runs at fp32 speed.
mode fp16: weight -> fp16 + Cast;  mode int8: weight -> int8 per-output-channel + DequantizeLinear.
usage: python -I weights_only.py in.onnx out.onnx fp16|int8"""
import os, sys
import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto
src, dst, mode = sys.argv[1:4]
int8_parts = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
m = onnx.load(src)
g = m.graph
init = {i.name: i for i in g.initializer}
users = {}
for n in g.node:
    for k, x in enumerate(n.input):
        users.setdefault(x, []).append((n, k))
new_nodes, done = [], 0
for name, t in list(init.items()):
    us = users.get(name, [])
    if not us or not all(n.op_type in ("Conv", "ConvTranspose") and k == 1 for n, k in us):
        continue
    w = numpy_helper.to_array(t)
    if w.size < 4096 or w.dtype != np.float32:
        continue
    g.initializer.remove(t)
    part = us[0][0].name.split("/")[1] if "/" in us[0][0].name else ""
    use8 = mode == "int8" and (int8_parts is None or part in int8_parts)
    if not use8:
        h = numpy_helper.from_array(w.astype(np.float16), name + "_h")
        g.initializer.append(h)
        new_nodes.append(helper.make_node("Cast", [name + "_h"], [name], to=TensorProto.FLOAT))
    else:
        axis = 1 if us[0][0].op_type == "ConvTranspose" else 0
        red = tuple(i for i in range(w.ndim) if i != axis)
        scale = np.abs(w).max(axis=red) / 127.0
        scale[scale == 0] = 1e-8
        shape = [1] * w.ndim; shape[axis] = -1
        q = np.clip(np.round(w / scale.reshape(shape)), -127, 127).astype(np.int8)
        g.initializer.append(numpy_helper.from_array(q, name + "_q"))
        g.initializer.append(numpy_helper.from_array(scale.astype(np.float32), name + "_s"))
        g.initializer.append(numpy_helper.from_array(np.zeros(scale.shape, np.int8), name + "_z"))
        new_nodes.append(helper.make_node("DequantizeLinear", [name + "_q", name + "_s", name + "_z"], [name], axis=axis))
    done += 1
for n in reversed(new_nodes):
    g.node.insert(0, n)
if mode == "int8":
    # DequantizeLinear with axis needs opset 13 (already).
    pass
onnx.save(m, dst)
print(mode, done, "weights", os.path.getsize(src), "->", os.path.getsize(dst))
