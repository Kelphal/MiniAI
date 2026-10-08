#!/usr/bin/env python3
"""Headless, offline FLUX.2-dev worker controlled by MiniAI."""
import argparse, os, sys, traceback
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
    if a.memory_budget_mb < 1024 and not torch.cuda.is_available():
        raise RuntimeError("Less than 1 GB of physical RAM remains after the 2 GB reserve and no CUDA GPU was detected. FLUX.2-dev is too large to safely start.")
    dtype = torch.bfloat16 if torch.cuda.is_available() and torch.cuda.is_bf16_supported() else torch.float16
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
