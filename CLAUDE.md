# AMD AI Server Stack

Docker Compose configurations for AMD ROCm-based AI workloads.

## Purpose

Version-controlled Docker Compose configurations for bringing up AI stack components on AMD GPU systems. This approach addresses the compatibility challenges AMD users face compared to NVIDIA, using Docker to modularize installation and avoid dependency conflicts.

## Architecture Philosophy

### Layering Concept

AI stacks involve large foundational technologies (ROCm, PyTorch) with smaller components layered on top. This repository maintains a stable ROCm + PyTorch base to avoid the "disk bloat" that comes from discrete stacks requiring different PyTorch builds.

### Foundational Images

- **ROCm**: AMD's GPU compute platform
- **PyTorch ROCm**: `rocm/pytorch:latest` (~29GB)
- **Ollama ROCm**: `ollama/ollama:rocm` (~6.4GB)

## Stack Components

### Core: Ollama (LLM Inference)

- **Port**: 11434
- **Image**: `ollama/ollama:rocm`
- **Models path**: `/home/daniel/ai/models/gguf` (host-bound)
- **Companion**: Open WebUI on port 3000

### STT (Speech-to-Text)

Three tiers of STT capability:

1. **Basic**: GPU-accelerated Whisper with punctuation restoration
2. **Enhanced**: Whisper + Ollama post-processing for clarity
3. **Advanced**: WhisperX for word-level diarization and SRT output

Models path: `/home/daniel/ai/models/stt`

### TTS (Text-to-Speech)

Natural-sounding local TTS for:
- Podcast generation (multi-presenter, voice cloning)
- General text-to-audio conversion

### Image Generation: ComfyUI

- **Port**: 8188
- Bind-mounted to existing installation with custom nodes preserved

## Service Exposure

Services are exposed via:
1. **Web UIs** (primary user interface)
2. **REST APIs** (programmatic access)
3. **MCP Servers** (natural language tool access via Claude)

## Host Paths

```
/home/daniel/ai/models/
├── gguf/          # Ollama/GGUF models
├── stt/           # Speech-to-text models
│   ├── finetunes/
│   ├── openai-whisper/
│   └── whisper-cpp/
├── tts/           # Text-to-speech models
├── loras/         # LoRA adapters
└── lmstudio/      # LM Studio models
```

## GPU Configuration

- **GPU**: AMD Radeon RX 7700 XT / 7800 XT (Navi 32, gfx1101)
- **VRAM**: 12GB
- **Required environment**:
  ```
  HSA_OVERRIDE_GFX_VERSION=11.0.1
  ROCM_PATH=/opt/rocm
  HIP_VISIBLE_DEVICES=0
  PYTORCH_ROCM_ARCH=gfx1101
  ```

## Control Panel

A bespoke web UI for managing this stack is available on port 8090.

- **Start/Stop/Restart** individual services
- **View logs** per service
- **GPU monitoring** (VRAM usage)
- **Direct links** to service web UIs

Run standalone: `cd control-panel && python app.py`
Or via Docker Compose (included in main compose file)

## Future Expansion Ideas

### TTS Models to Investigate

These models show promise for ROCm compatibility:

- **Microsoft Vibe Voice**: High-quality neural TTS
- **Dia (D-I-A)**: Hugging Face model worth testing
- **Kokoro**: Already tested, builds but needs ROCm optimization
- **Fish Speech**: Multilingual TTS option

### ASR/STT Alternatives

- **WhisperX**: Word-level timestamps, speaker diarization
- **Faster-Whisper**: CTranslate2 backend (may need CUDA->ROCm work)
- **Whisper.cpp**: CPU fallback or ROCm via hipBLAS
- **Fine-tuned Whisper**: Custom models for specific accents/domains

### Other Potential Additions

- **Open WebUI**: Chat interface for Ollama (pairs well with LLM stack)
- **SillyTavern**: Alternative chat UI with character support
- **Automatic1111**: Alternative to ComfyUI for image generation
- **RVC**: Real-time voice conversion
- **Tortoise-TTS**: Slower but very high quality voice cloning

### MCP Server Integration

Services could expose MCP (Model Context Protocol) servers for Claude integration:
- Whisper MCP for voice-to-text in conversations
- TTS MCP for Claude to speak responses
- Image generation MCP for inline image creation

## Notes for Other Users

Paths in these configurations are specific to the author's filesystem. You will need to modify:
- Volume mount paths (`/home/daniel/...`)
- Model storage locations
- Any hardcoded user references
