# MiniAI

**MiniAI** is a Windows x64 local AI application with an integrated chat interface, image search, teaching tools, file workspace, and Image Generator.

## Installation

1. Run `MiniAI_Installer_v5.0.0.cmd`.
2. Choose the installation folder.
3. Select **Install MiniAI** for a normal installation or **Fresh Install** to replace MiniAI-managed files in the selected folder.
4. Keep the installer open until the progress status reports completion.

The installer package contains the MiniAI application and setup scripts. The chat model is downloaded during installation. Large optional image-generation model files are not bundled into the installer.

## Image Generator

Image generation is integrated into the MiniAI interface and uses a local worker. After a compatible image model and runtime are installed, generation can operate offline. Image Search and locally saved references can help with prompts, but collecting references does not retrain the image model.

The current image worker requires a compatible local model directory at `Models/Flux2`. The full model is very large and generally requires substantial GPU memory; low-memory systems with integrated graphics may not be able to run it at a practical speed. Do not assume that a 6.3 GB physical-memory system can run the full model.

## Storage

- The installer writes the application and its managed data to the selected MiniAI install location, except that the current Windows C: path resolver uses the current user's Local AppData directory.
- Fresh Install removes MiniAI-managed models, runtime files, conversations, and learned data under the selected install folder.
- Do not choose a folder that contains unrelated files.

## Build

The repository's Windows workflow builds the application and packages a single-file CMD installer artifact. Each generated artifact must pass a clean-install test on Windows before being treated as a public release.
