# AMD AI Server Stack

Docker Compose configurations for AMD ROCm-based AI workloads.

## Purpose

Version-controlled Docker Compose configurations for bringing up AI stack components on AMD GPU systems. This approach addresses the compatibility challenges AMD users face compared to NVIDIA, using Docker to modularize installation and avoid dependency conflicts.

**Goals:**
1. **Single source of truth** for local AI services - everything brought up from here
2. **Unified stack** that starts on boot with all needed services available
3. **No port conflicts** - services properly spaced out
4. **Visual management** - stop/start services without editing compose files or Portainer
5. **MCP-ready** - services expose APIs that can be wrapped by MCP servers for Claude integration

## Architecture Philosophy

### Why Docker Over Conda

Previous attempts used Conda environments to share PyTorch/ROCm across workloads. While functional, this approach had complications and felt like the wrong tool. Docker provides:

- **Layer caching**: Reuse large foundational layers (ROCm, PyTorch) across stacks without duplicating storage
- **Isolation**: Services don't conflict with each other or host packages
- **Idle efficiency**: Containers don't consume resources when idle (a misconception that held back adoption)
- **Reproducibility**: Consistent environments regardless of host state

The trade-off is isolation from host, but GPU passthrough works well with proper configuration.

### Layering Concept

AI stacks involve large foundational technologies (ROCm, PyTorch) with smaller components layered on top. This repository maintains a stable ROCm + PyTorch base to avoid the "disk bloat" that comes from discrete stacks requiring different PyTorch builds.

**Key principle**: Don't use bleeding edge for the backbone. Keep PyTorch/ROCm stable and reliable, then layer application-specific components on top.

### Foundational Images

- **ROCm**: AMD's GPU compute platform
- **PyTorch ROCm**: `rocm/pytorch:latest` (~29GB)
- **Ollama ROCm**: `ollama/ollama:rocm` (~6.4GB)

### Consolidation Strategy

Prefer one setup over duplicates. If Ollama exists both on host and in Docker, consolidate to Docker and migrate models rather than maintaining parallel installations. Avoid re-pulling gigantic models.

## Stack Components

### Core: Ollama (LLM Inference)

- **Port**: 11434
- **Image**: `ollama/ollama:rocm`
- **Models path**: `/home/daniel/ai/models/gguf` (host-bound)
- **Companion**: Open WebUI on port 3000

**Primary use**: Scripting and text processing rather than chat interfaces. Key value is sitting alongside other stack components for combined workflows (e.g., Whisper → Ollama for enhanced transcription).

### STT (Speech-to-Text)

Three tiers of STT capability:

1. **Basic**: GPU-accelerated Whisper with punctuation restoration
2. **Enhanced**: Whisper + Ollama post-processing for clarity
3. **Advanced**: WhisperX for word-level diarization and SRT output

Models path: `/home/daniel/ai/models/stt`

### TTS (Text-to-Speech)

**Status**: Missing component - needs implementation

Natural-sounding local TTS for:
- Podcast generation (multi-presenter, voice cloning)
- General text-to-audio conversion

**Podcast workflow**: Agent creates script → script diarized by two hosts → concatenated with prompt → episode output. This is a separate project but depends on TTS being available in this stack.

**Requirements**:
- Human-sounding, natural voices (baseline requirement)
- Voice cloning nice-to-have but not essential - stock voices acceptable
- Must run on AMD/ROCm
- Ease of setup prioritized over feature completeness

### Image Generation: ComfyUI

- **Port**: 8188
- Bind-mounted to existing installation with custom nodes preserved

## Service Exposure

Services are exposed via:
1. **Web UIs** (primary user interface)
2. **REST APIs** (programmatic access)
3. **MCP Servers** (natural language tool access via Claude)

### API Architecture Vision

**Current approach**: Each service exposes its own local API

**Future vision**: Single unified local AI API with OpenAPI schema that proxies to all backend services. Rather than four parallel APIs (Ollama, STT, Whisper, ComfyUI), one API that routes to appropriate backends. This simplifies MCP server development - one schema to wrap instead of many.

**Implementation path**:
1. First ensure all services provide local APIs with definitions
2. Control panel links to individual API definitions
3. Optionally add unified proxy layer later

### MCP Integration Strategy

The stack's primary purpose is providing local AI capabilities for MCP servers to consume. Example: A local transcription MCP server shouldn't need to spin up its own Whisper stack - it should find the API already running and accessible.

**Key insight**: Don't pack application logic into this server. Keep it as core services only. Specifics handled by applications consuming the APIs.

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

- **WhisperX**: Word-level timestamps, speaker diarization - useful for podcast workflow, nice-to-have if low background weight
- **Faster-Whisper**: CTranslate2 backend (may need CUDA->ROCm work)
- **Whisper.cpp**: CPU fallback or ROCm via hipBLAS
- **Fine-tuned Whisper**: Custom models for specific accents/domains
- **VAD (Voice Activity Detection)**: Useful component for speech detection pipelines - future consideration

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

**Note**: MCP wraps APIs - so long as services provide OpenAPI-compatible local APIs, they're easy to scaffold into MCP servers. The unified API vision would make this even simpler.

## Notes for Other Users

Paths in these configurations are specific to the author's filesystem. You will need to modify:
- Volume mount paths (`/home/daniel/...`)
- Model storage locations
- Any hardcoded user references
