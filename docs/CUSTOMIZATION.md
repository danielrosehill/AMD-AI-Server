# Customizing AMD AI Server Stack

This guide explains how to adapt the configurations for your own system.

## Path Configuration

All host paths are configured via the `.env` file. Copy `.env.example` to `.env` and modify:

```bash
# Your base models directory
MODELS_BASE=/home/youruser/ai/models

# Individual paths (derived from MODELS_BASE or set explicitly)
OLLAMA_MODELS=${MODELS_BASE}/gguf
STT_MODELS=${MODELS_BASE}/stt
TTS_MODELS=${MODELS_BASE}/tts

# ComfyUI installation (if using bind mount)
COMFYUI_PATH=/home/youruser/ComfyUI
```

## GPU Configuration

### Finding Your GFX Version

Determine your AMD GPU's GFX version:

```bash
# Method 1: rocm-smi
rocm-smi --showproductname

# Method 2: Device info
cat /sys/class/drm/card0/device/uevent | grep DRIVER

# Method 3: lspci
lspci | grep VGA
```

### Common GFX Values

| GPU Family | Cards | GFX Version | HSA_OVERRIDE |
|------------|-------|-------------|--------------|
| RDNA 3 | RX 7900 XTX/XT | gfx1100 | 11.0.0 |
| RDNA 3 | RX 7800 XT, 7700 XT | gfx1101 | 11.0.1 |
| RDNA 3 | RX 7600 | gfx1102 | 11.0.2 |
| RDNA 2 | RX 6900 XT, 6800 XT/XT | gfx1030 | 10.3.0 |
| RDNA 2 | RX 6700 XT | gfx1031 | 10.3.1 |
| CDNA 2 | MI200 series | gfx90a | 9.0.10 |
| CDNA | MI100 | gfx908 | 9.0.8 |

Update your `.env`:

```bash
HSA_OVERRIDE_GFX_VERSION=11.0.1  # For RX 7700/7800 XT
PYTORCH_ROCM_ARCH=gfx1101
```

## Adding New Services

### 1. Create Stack Directory

```bash
mkdir -p stacks/myservice
```

### 2. Create docker-compose.yml

```yaml
# stacks/myservice/docker-compose.yml
services:
  myservice:
    image: myimage:rocm
    container_name: myservice-rocm
    restart: unless-stopped
    ports:
      - "${MYSERVICE_PORT:-8000}:8000"
    environment:
      - HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-11.0.1}
      - ROCM_PATH=${ROCM_PATH:-/opt/rocm}
      - HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-0}
    volumes:
      - ./data:/app/data
    devices:
      - /dev/kfd
      - /dev/dri
    group_add:
      - video
      - render
    security_opt:
      - seccomp:unconfined
    ipc: host
    networks:
      - ai-stack

networks:
  ai-stack:
    name: ${DOCKER_NETWORK:-ai-stack}
    external: true
```

### 3. Add to Start Script

Edit `scripts/start.sh` to add your service:

```bash
start_myservice() {
    print_status "Starting MyService..."
    cd "$REPO_DIR/stacks/myservice"
    docker compose up -d
}
```

### 4. Add Environment Variables

Add to `.env`:

```bash
MYSERVICE_PORT=8000
```

## Memory Optimization

### Reducing VRAM Usage

For GPUs with less than 12GB VRAM:

1. **Ollama**: Use smaller quantizations (Q4_K_M instead of Q8_0)
2. **Whisper**: Use `tiny` or `base` model instead of `large`
3. **ComfyUI**: Enable `--lowvram` or `--cpu` flags for models

### Environment Variables for Low Memory

```bash
# In docker-compose.yml environment section
- PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
- CUDA_VISIBLE_DEVICES=0
```

## Network Modes

### Bridge Mode (Default)

Services communicate via Docker network:
```yaml
networks:
  - ai-stack
```

### Host Mode

For services needing direct network access:
```yaml
network_mode: host
```

Note: Port mappings are ignored in host mode.

## Persistent Data

### Volumes vs Bind Mounts

**Named Volumes** (managed by Docker):
```yaml
volumes:
  - mydata:/app/data

volumes:
  mydata:
```

**Bind Mounts** (host directory):
```yaml
volumes:
  - /home/user/data:/app/data
```

Use bind mounts when you need direct access to files from the host.

## Building Custom Images

### With ROCm Base

```dockerfile
FROM rocm/pytorch:latest

# Install dependencies
RUN pip install --no-cache-dir mypackage

# Copy application
COPY . /app

WORKDIR /app
CMD ["python", "main.py"]
```

### Building

```bash
cd stacks/myservice
docker compose build --no-cache
```

## Troubleshooting Configuration

### Permission Denied on GPU

Add user to required groups:
```bash
sudo usermod -aG video,render $USER
# Log out and back in
```

### Container Can't Find GPU

Verify devices are passed:
```yaml
devices:
  - /dev/kfd
  - /dev/dri
```

### Wrong GFX Version Error

Check logs for messages like "Invalid gfx target". Update `HSA_OVERRIDE_GFX_VERSION` in `.env`.

### Out of Shared Memory

Increase shared memory:
```yaml
shm_size: '8gb'
```

Or use host IPC:
```yaml
ipc: host
```
