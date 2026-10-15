"""Converts a Hugging Face Whisper checkpoint (fine-tune) to an openai-whisper .pt
that whisper.load_model() (and sherpa-onnx's export script) can read.
usage: python -I hf_to_openai.py <hf_dir> <out.pt>"""
import json, os, re, sys
import torch
from safetensors.torch import load_file
d, out = sys.argv[1:3]
cfg = json.load(open(os.path.join(d, "config.json")))
sd = load_file(os.path.join(d, "model.safetensors"))
rules = [
    (r"^model\.", ""), (r"\.layers\.", ".blocks."), (r"\.self_attn\.q_proj", ".attn.query"), (r"\.self_attn\.k_proj", ".attn.key"),
    (r"\.self_attn\.v_proj", ".attn.value"), (r"\.self_attn\.out_proj", ".attn.out"), (r"\.encoder_attn\.q_proj", ".cross_attn.query"),
    (r"\.encoder_attn\.k_proj", ".cross_attn.key"), (r"\.encoder_attn\.v_proj", ".cross_attn.value"), (r"\.encoder_attn\.out_proj", ".cross_attn.out"),
    (r"\.self_attn_layer_norm", ".attn_ln"), (r"\.encoder_attn_layer_norm", ".cross_attn_ln"), (r"\.final_layer_norm", ".mlp_ln"),
    (r"\.fc1\.", ".mlp.0."), (r"\.fc2\.", ".mlp.2."), (r"^encoder\.layer_norm\.", "encoder.ln_post."), (r"^decoder\.layer_norm\.", "decoder.ln."),
    (r"^encoder\.embed_positions\.weight", "encoder.positional_embedding"), (r"^decoder\.embed_positions\.weight", "decoder.positional_embedding"),
    (r"^decoder\.embed_tokens\.weight", "decoder.token_embedding.weight"),
]
new = {}
for k, v in sd.items():
    if k.startswith("proj_out"): continue
    n = k
    for a, b in rules: n = re.sub(a, b, n)
    new[n] = v.float()
dims = dict(n_mels=cfg["num_mel_bins"], n_vocab=cfg["vocab_size"], n_audio_ctx=cfg["max_source_positions"], n_audio_state=cfg["d_model"],
            n_audio_head=cfg["encoder_attention_heads"], n_audio_layer=cfg["encoder_layers"], n_text_ctx=cfg["max_target_positions"],
            n_text_state=cfg["d_model"], n_text_head=cfg["decoder_attention_heads"], n_text_layer=cfg["decoder_layers"])
torch.save({"dims": dims, "model_state_dict": new}, out)
import whisper
m = whisper.load_model(out)  # strict load: fails if any key is wrong
print("ok", dims, sum(p.numel() for p in m.parameters()))
