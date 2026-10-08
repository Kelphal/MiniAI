# MiniAI 5.0 development branch

This branch is being developed from the existing v4.11.1 release package rather than replacing the project with a fresh application.

## Changes currently staged in source
- Restores the embedded Go source and HTML UI into ordinary source files so they can be reviewed and built.
- Adds a dedicated FLUX.2-dev Image Generator tab in the existing MiniAI UI.
- Adds a headless local worker path controlled by MiniAI; it does not open a separate generator GUI.
- Adds a physical-memory status endpoint and budgets currently available physical RAM minus a 2 GiB safety reserve. Pagefile capacity is not treated as physical RAM.
- Generation is configured for local-only model loading; it will not silently download model weights while offline.

## Important: development build, not a finished release
- FLUX.2-dev weights and a compatible Python/PyTorch/Diffusers runtime are not bundled here yet.
- The worker expects a local Diffusers model directory at `Models/Flux2`. The model must be installed in advance.
- FLUX.2-dev is a 32-billion-parameter model. On a machine with 6.3 GB physical RAM, the current worker intentionally refuses CPU-only generation instead of risking Windows memory exhaustion. A compatible quantized local checkpoint and substantial GPU VRAM are needed for a more practical path.
- The optional image-learning/reference collection is separate from FLUX's model weights. It can support retrieval and reference guidance; storing images does not retrain FLUX.
- A conservative, reversible process optimizer now lowers priority only for a short allowlist of known noncritical background apps during generation, snapshots their process IDs/start times/original priorities, and restores them afterward. It does not kill processes. It still needs Windows runtime testing.
- The optional visual-data installer and final faster/idempotent v5 installer are not implemented yet. The current workflow builds a development ZIP, not the final self-contained installer.

## Build
The repository now includes a Windows x64 build workflow. You can also build with a Windows Go toolchain using `go build -o MiniAI.exe .`. Test in a separate directory and back up existing MiniAI data before trying a development build.
