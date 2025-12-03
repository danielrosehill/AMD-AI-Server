# Troubleshooting AMD AI Server Stack

Common issues and solutions for running AI workloads on AMD GPUs.

## GPU Issues

### "No GPU detected" or ROCm Errors

**Symptoms:**
- Services fall back to CPU
- `rocm-smi` fails
- PyTorch reports `torch.cuda.is_available() = False`

**Solutions:**

1. **Check device nodes exist:**
   ```bash
   ls -la /dev/kfd /dev/dri/renderD128
   ```
   If missing, ROCm may not be properly installed.

2. **Verify user groups:**
   ```bash
   groups $USER | grep -E 'video|render'
   ```
   Add if missing:
   ```bash
   sudo usermod -aG video,render $USER
   # Log out and back in
   ```

3. **Check ROCm installation:**
   ```bash
   rocm-smi --showproductname
   ```

4. **Verify HSA override:**
   ```bash
   docker exec ollama-rocm env | grep HSA
   ```
   Should show: `HSA_OVERRIDE_GFX_VERSION=11.0.1` (or your GFX version)

### "Invalid gfx target" Error

**Cause:** Wrong `HSA_OVERRIDE_GFX_VERSION` for your GPU.

**Solution:** Find correct value:
```bash
# Check your GPU
rocm-smi --showproductname

# Common values:
# RX 7900 XTX/XT (gfx1100) -> 11.0.0
# RX 7800/7700 XT (gfx1101) -> 11.0.1
# RX 7600 (gfx1102) -> 11.0.2
```

Update `.env`:
```bash
HSA_OVERRIDE_GFX_VERSION=11.0.1
```

### GPU Memory Errors

**Symptoms:**
- Out of memory errors
- Model fails to load
- Crashes during inference

**Solutions:**

1. **Reduce model size:**
   - Use smaller quantizations (Q4 instead of Q8)
   - Use smaller models

2. **Limit concurrent services:**
   - Stop ComfyUI when using large LLMs
   - Run one heavy service at a time

3. **Check VRAM usage:**
   ```bash
   cat /sys/class/drm/card0/device/mem_info_vram_used
   cat /sys/class/drm/card0/device/mem_info_vram_total
   ```

## Container Issues

### Container Won't Start

**Check logs:**
```bash
docker logs ollama-rocm
docker logs whisper-rocm
docker logs comfyui
```

**Common causes:**

1. **Port already in use:**
   ```bash
   # Find what's using the port
   sudo lsof -i :11434

   # Change port in .env
   OLLAMA_PORT=11435
   ```

2. **Volume mount doesn't exist:**
   ```bash
   # Create directories
   mkdir -p ~/ai/models/gguf
   mkdir -p ~/ai/models/stt
   ```

3. **Network doesn't exist:**
   ```bash
   docker network create ai-stack
   ```

### Container Exits Immediately

**Check exit code:**
```bash
docker ps -a --filter "name=ollama-rocm" --format "{{.Status}}"
```

**Common causes:**

1. **Missing dependencies in custom Dockerfile**
2. **Incorrect command/entrypoint**
3. **File permissions on bind mounts**

### Network Issues Between Containers

**Verify network:**
```bash
docker network inspect ai-stack
```

**Test connectivity:**
```bash
# From one container
docker exec open-webui ping ollama
docker exec open-webui curl http://ollama:11434/api/tags
```

## Service-Specific Issues

### Ollama

**Model won't load:**
```bash
# Check available space
df -h

# Check model files
docker exec ollama-rocm ls -la /root/.ollama/models/
```

**Slow inference:**
- Verify GPU is being used (check with `rocm-smi` during inference)
- Check model isn't too large for VRAM

### Whisper STT

**Transcription fails:**
```bash
# Test API directly
curl http://localhost:9000/health

# Check logs
docker logs whisper-rocm
```

**Wrong language detected:**
- Specify language in API call:
  ```bash
  curl -X POST -F 'file=@audio.mp3' -F 'language=en' http://localhost:9000/transcribe
  ```

### ComfyUI

**Custom nodes not loading:**
- Bind mount may not include custom_nodes directory
- Check path in docker-compose.yml

**Models not found:**
- Verify COMFYUI_PATH in .env points to your ComfyUI installation
- Check model paths inside container:
  ```bash
  docker exec comfyui ls /root/models/checkpoints/
  ```

### Open WebUI

**Can't connect to Ollama:**
```bash
# Verify Ollama URL
docker exec open-webui env | grep OLLAMA

# Should be: OLLAMA_BASE_URL=http://ollama:11434
```

**Database issues:**
```bash
# Reset data (WARNING: loses settings)
docker volume rm amd-ai-server_open-webui-data
```

## Performance Issues

### Slow Startup

ROCm containers are large (~30GB). First start downloads images.

**Tip:** Pre-pull images:
```bash
docker pull ollama/ollama:rocm
docker pull rocm/pytorch:latest
docker pull yanwk/comfyui-boot:rocm
```

### High CPU Usage

**Cause:** GPU not being used, falling back to CPU.

**Check:**
```bash
# During inference, GPU usage should increase
watch -n 1 cat /sys/class/drm/card0/device/gpu_busy_percent
```

### Memory Leaks

Some models leak memory over time.

**Solution:** Restart containers periodically:
```bash
docker restart ollama-rocm
```

Or set up automatic restarts in compose:
```yaml
deploy:
  restart_policy:
    condition: any
    delay: 5s
```

## Getting Help

### Collect Debug Info

```bash
# System info
uname -a
rocm-smi --showallinfo

# Docker info
docker version
docker info

# Container logs
docker logs ollama-rocm > ollama.log 2>&1
docker logs whisper-rocm > whisper.log 2>&1

# Environment
docker exec ollama-rocm env > ollama-env.txt
```

### Useful Commands

```bash
# See all containers (including stopped)
docker ps -a

# Follow logs in real-time
docker logs -f ollama-rocm

# Execute command in container
docker exec -it ollama-rocm bash

# Inspect container config
docker inspect ollama-rocm

# Check resource usage
docker stats
```
