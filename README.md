# AMD AI Server Stack

Docker Compose configurations for running AI workloads on AMD GPUs with ROCm.

## Overview

This repository provides a modular, Docker-based approach to deploying AI services on AMD hardware. Rather than managing complex conda environments and dependency conflicts, each service runs in its own container with ROCm GPU acceleration.

### Why Docker for AMD AI?

AMD users face unique challenges compared to NVIDIA:
- Fewer pre-built wheels and packages
- ROCm version compatibility issues
- PyTorch builds often conflict across tools

Docker solves this by:
- Isolating dependencies per service
- Using official ROCm-enabled images
- Enabling reproducible deployments
- Avoiding "disk bloat" from multiple PyTorch installations

## System Requirements

### Hardware (Reference System)

| Component | Specification |
|-----------|---------------|
| GPU | AMD Radeon RX 7700 XT / 7800 XT (Navi 32, gfx1101) |
| VRAM | 12 GB |
| CPU | Intel Core i7-12700F (20 threads) |
| RAM | 64 GB |
| Storage | ~40GB+ free for Docker images and models |

### Software

- Docker with GPU support
- ROCm installed on host (`/opt/rocm`)
- User in `video` and `render` groups
- Device nodes: `/dev/kfd`, `/dev/dri/renderD128`

## Services

### Core Infrastructure

| Service | Port | Image | Description |
|---------|------|-------|-------------|
| Ollama | 11434 | `ollama/ollama:rocm` | LLM inference server |
| Open WebUI | 3000 | `ghcr.io/open-webui/open-webui:main` | Chat interface for Ollama |
| PyTorch ROCm | - | `rocm/pytorch:latest` | Base environment for ML tasks |

### Speech Services

| Service | Port | Description |
|---------|------|-------------|
| Whisper | 9000 | GPU-accelerated speech-to-text |
| Whisper Enhanced | 9001 | STT with LLM post-processing |
| WhisperX | 9002 | Word-level diarization + SRT output |

### Media Generation

| Service | Port | Description |
|---------|------|-------------|
| ComfyUI | 8188 | Image generation and manipulation |
| Kokoro TTS | 8880 | Natural-sounding text-to-speech |

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/danielrosehill/AMD-AI-Server.git
cd AMD-AI-Server

# Copy example environment file
cp .env.example .env

# Edit paths for your system
nano .env
```

### 2. Start Services

```bash
# Start all services
./scripts/start.sh

# Or start individual services
./scripts/start.sh ollama
./scripts/start.sh whisper
./scripts/start.sh comfyui
```

### 3. Verify GPU Access

```bash
./scripts/check-gpu.sh
```

## Directory Structure

```
AMD-AI-Server/
├── README.md
├── CLAUDE.md                    # AI agent context
├── .env.example                 # Environment template
├── docker-compose.yml           # Main orchestration file
├── stacks/
│   ├── ollama/
│   │   └── docker-compose.yml   # Ollama + Open WebUI
│   ├── whisper/
│   │   ├── docker-compose.yml   # Basic Whisper
│   │   └── Dockerfile
│   ├── whisper-enhanced/
│   │   └── docker-compose.yml   # Whisper + Ollama post-processing
│   ├── comfyui/
│   │   ├── docker-compose.yml
│   │   └── Dockerfile
│   ├── tts/
│   │   └── docker-compose.yml   # Text-to-speech
│   └── pytorch/
│       └── docker-compose.yml   # Base PyTorch environment
├── scripts/
│   ├── start.sh                 # Start services
│   ├── stop.sh                  # Stop services
│   ├── check-gpu.sh             # Verify GPU access
│   └── status.sh                # Show service status
└── docs/
    ├── CUSTOMIZATION.md         # Adapting for your system
    └── TROUBLESHOOTING.md       # Common issues
```

## Configuration

### Environment Variables

Create a `.env` file (see `.env.example`):

```bash
# Host paths for model storage
MODELS_BASE=/home/youruser/ai/models
OLLAMA_MODELS=${MODELS_BASE}/gguf
STT_MODELS=${MODELS_BASE}/stt
TTS_MODELS=${MODELS_BASE}/tts

# GPU configuration (gfx1101 for RX 7700/7800 XT)
HSA_OVERRIDE_GFX_VERSION=11.0.1
ROCM_PATH=/opt/rocm
HIP_VISIBLE_DEVICES=0
PYTORCH_ROCM_ARCH=gfx1101
```

### GPU Environment Variables

These are critical for gfx1101 (Navi 32) GPUs:

| Variable | Value | Purpose |
|----------|-------|---------|
| `HSA_OVERRIDE_GFX_VERSION` | `11.0.1` | ROCm compatibility for gfx1101 |
| `ROCM_PATH` | `/opt/rocm` | ROCm installation path |
| `HIP_VISIBLE_DEVICES` | `0` | GPU selection |
| `PYTORCH_ROCM_ARCH` | `gfx1101` | PyTorch GPU architecture |

## Usage Examples

### Ollama

```bash
# List models
docker exec ollama-rocm ollama list

# Pull a model
docker exec ollama-rocm ollama pull llama3.2

# Run inference
docker exec ollama-rocm ollama run llama3.2 "Hello!"

# API access
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'
```

### Whisper STT

```bash
# Health check
curl http://localhost:9000/health

# Transcribe audio
curl -X POST -F 'file=@audio.mp3' http://localhost:9000/transcribe

# With language hint
curl -X POST -F 'file=@audio.mp3' -F 'language=en' http://localhost:9000/transcribe
```

### ComfyUI

1. Open http://localhost:8188 in browser
2. Load or create workflows
3. All existing models and custom nodes are available

## Performance

Expected performance on RX 7700 XT / 7800 XT (12GB VRAM):

| Task | Performance |
|------|-------------|
| LLM (7B models) | 20-40 tokens/sec |
| Whisper (base) | ~10x realtime |
| Whisper (large-v3) | ~2-3x realtime |
| SDXL image gen | ~15-20 sec/image |

## Troubleshooting

### GPU Not Detected

```bash
# Check host GPU
ls -la /dev/kfd /dev/dri/render*

# Verify user groups
groups $USER | grep -E 'video|render'

# Check ROCm
rocm-smi --showproductname
```

### Container Won't Start

```bash
# Check logs
docker logs ollama-rocm
docker logs whisper-rocm

# Verify environment
docker exec ollama-rocm env | grep HSA
```

### Out of Memory

- Reduce model size (use smaller quantizations)
- Enable `--low-vram` flags where available
- Run fewer concurrent services

## Adapting for Your System

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for:
- Modifying paths for your filesystem
- Adjusting for different AMD GPUs (gfx values)
- Adding new services
- Memory and performance tuning

## Contributing

Contributions welcome, especially:
- Configurations for other AMD GPUs
- Additional ROCm-compatible services
- Performance optimizations
- Documentation improvements

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- [ROCm](https://rocm.docs.amd.com/) - AMD's GPU compute platform
- [Ollama](https://ollama.ai/) - Local LLM inference
- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) - Image generation
