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

**Primary use**: Scripting and text processing rather than chat interfaces. Key value is sitting alongside other stack components for combined workflows (e.g., Whisper → Ollama for enhanced transcription).

### STT (Speech-to-Text): Whisper

- **Port**: 9000
- **Model**: large-v3-turbo (default)
- **Models path**: `/home/daniel/ai/models/stt`

**Features**:
- GPU-accelerated transcription via ROCm
- Support for fine-tuned models
- Multiple endpoints: `/transcribe`, `/transcribe/finetune`

### TTS: Chatterbox (Text-to-Speech)

- **Port**: 8880
- **Image**: Built from [devnen/Chatterbox-TTS-Server](https://github.com/devnen/Chatterbox-TTS-Server) (git submodule)
- **Web UI**: http://localhost:8880
- **API Docs**: http://localhost:8880/docs

**Features**:
- Zero-shot voice cloning from 5 seconds of audio
- Emotion exaggeration control
- OpenAI-compatible API endpoint
- Native ROCm support (PyTorch 2.6.0 + ROCm 6.4.1)
- Audiobook-scale text processing with intelligent chunking
- MIT licensed

**Upstream**: The Chatterbox model is by [Resemble AI](https://www.resemble.ai/chatterbox/) - in blind tests, 63% of listeners preferred it over ElevenLabs.

**Data paths**:
- Voices: `./stacks/chatterbox/data/voices/`
- Reference audio: `./stacks/chatterbox/data/reference_audio/`
- Outputs: `./stacks/chatterbox/data/outputs/`

**Podcast workflow**: Agent creates script → script diarized by two hosts → TTS generates audio per speaker → concatenated → episode output.

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

### ASR/STT Enhancements

- **WhisperX**: Word-level timestamps, speaker diarization - useful for podcast workflow
- **Whisper + Ollama**: Post-processing pipeline for cleanup (via MCP `transcribe_clean` tool)
- **Fine-tuned Whisper**: Custom models for specific accents/domains (already supported via `/transcribe/finetune` endpoint)

### Other Potential Additions

- **Open WebUI**: Chat interface for Ollama
- **Alternative TTS**: Dia, Kokoro, or Tortoise-TTS if Chatterbox doesn't meet needs
- **Automatic1111**: Alternative to ComfyUI for image generation
- **RVC**: Real-time voice conversion

## MCP Server Integration

The stack includes a unified MCP server (`local-ai`) that provides Claude with direct access to local AI services.

### Available Tools

| Tool | Description |
|------|-------------|
| `transcribe_raw` | Transcribe audio using large-v3-turbo (general purpose) |
| `transcribe_finetune` | Transcribe using fine-tuned Whisper model (Daniel's voice) |
| `transcribe_clean` | Transcribe + Ollama cleanup (fixes punctuation, removes fillers) |
| `whisper_health` | Check Whisper service status |

### Setup

```bash
cd mcp-server
uv venv && source .venv/bin/activate && uv pip install -e .
```

### Configuration

**Via MCPM:**
```bash
mcpm new local-ai \
  --type stdio \
  --command "/path/to/mcp-server/.venv/bin/python" \
  --args "-m local_ai_mcp.server" \
  --env "WHISPER_URL=http://localhost:9000,OLLAMA_URL=http://localhost:11434,OLLAMA_MODEL=llama3.2" \
  --force
```

**Via Claude Desktop config:**
```json
{
  "mcpServers": {
    "local-ai": {
      "command": "/path/to/mcp-server/.venv/bin/python",
      "args": ["-m", "local_ai_mcp.server"],
      "env": {
        "WHISPER_URL": "http://localhost:9000",
        "OLLAMA_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2"
      }
    }
  }
}
```

### Control Panel Integration

The control panel (port 8090) includes an MCP Integration panel showing:
- Available tools and descriptions
- Copy-paste configuration snippets for MCPM and Claude Desktop

## Notes for Other Users

Paths in these configurations are specific to the author's filesystem. You will need to modify:
- Volume mount paths (`/home/daniel/...`)
- Model storage locations
- Any hardcoded user references
