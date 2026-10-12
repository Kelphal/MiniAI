#!/usr/bin/env python3
"""Headless, offline FLUX.2-dev worker controlled by MiniAI."""
import argparse, json, os, sys, traceback
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--prompt", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--width", type=int, default=512)
    p.add_argument("--height", type=int, default=512)
    p.add_argument("--steps", type=int, default=4)
    p.add_argument("--memory-budget-mb", type=int, default=0)
    a = p.parse_args()
    model = Path(a.model)
    if not model.is_dir() or not (model / "model_index.json").exists():
        raise RuntimeError("Local Diffusers model files were not found. Downloads are intentionally disabled.")
    try:
        import torch
        from diffusers import Flux2Pipeline
    except Exception as exc:
        raise RuntimeError("Install a compatible local PyTorch and Diffusers runtime: " + str(exc))
    has_cuda = torch.cuda.is_available()
    quantized = "4bit" in str(model).lower() or any((model / name).exists() for name in ("quantization_config.json", "transformer/quantization_config.json"))
    for config_path in (model / "config.json", model / "transformer" / "config.json"):
        try:
            with config_path.open("r", encoding="utf-8") as handle:
                config_data = json.load(handle)
            if config_data.get("quantization_config") or config_data.get("quantization"):
                quantized = True
        except (OSError, ValueError):
            pass
    if not quantized and a.memory_budget_mb < 96 * 1024:
        raise RuntimeError("Safe stop: the installed FLUX.2-dev model is not identified as quantized and this worker requires a very large physical-RAM budget to load it safely. MiniAI will not risk exhausting Windows memory.")
    if quantized and a.memory_budget_mb < 24 * 1024:
        raise RuntimeError("Safe stop: the detected quantized FLUX.2-dev path still needs at least 24 GiB of available physical-RAM budget for this offline worker.")
    if has_cuda:
        free_vram, total_vram = torch.cuda.mem_get_info()
        if free_vram < 24 * 1024**3:
            raise RuntimeError("Safe stop: less than 24 GiB of free GPU VRAM is available. This worker does not yet support the remote text encoder or every quantized FLUX.2-dev layout.")
    elif quantized:
        raise RuntimeError("Safe stop: this worker currently requires a compatible CUDA GPU for the quantized FLUX.2-dev path.")
    dtype = torch.bfloat16 if has_cuda and torch.cuda.is_bf16_supported() else torch.float16
    # Local-only loading prevents an offline generation request from downloading model files.
    pipe = Flux2Pipeline.from_pretrained(str(model), torch_dtype=dtype, local_files_only=True)
    if torch.cuda.is_available():
        try:
            pipe.enable_model_cpu_offload()
        except Exception:
            pipe.to("cuda")
    else:
        try:
            pipe.enable_sequential_cpu_offload()
        except Exception:
            pipe.to("cpu")
    seed = int.from_bytes(os.urandom(4), "little")
    generator = torch.Generator(device="cpu").manual_seed(seed)
    result = pipe(prompt=a.prompt, width=a.width, height=a.height, num_inference_steps=a.steps, generator=generator)
    out = Path(a.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    result.images[0].save(out)
    print("Generated", out)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("FLUX_WORKER_ERROR:", exc, file=sys.stderr)
        traceback.print_exc()
        sys.exit(2)
