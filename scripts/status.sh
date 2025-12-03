#!/bin/bash
# AMD AI Server Stack - Service Status

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AMD AI Server Stack - Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check each known container
containers=(
    "ollama-rocm:Ollama:11434"
    "open-webui:Open WebUI:3000"
    "comfyui:ComfyUI:8188"
    "whisper-rocm:Whisper STT:9000"
    "kokoro-tts:Kokoro TTS:8880"
    "pytorch-rocm:PyTorch:-"
)

printf "%-20s %-12s %-10s\n" "SERVICE" "STATUS" "PORT"
printf "%-20s %-12s %-10s\n" "-------" "------" "----"

for entry in "${containers[@]}"; do
    IFS=':' read -r container name port <<< "$entry"

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status="${GREEN}running${NC}"
        if [[ "$port" != "-" ]]; then
            port_info="$port"
        else
            port_info="-"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        status="${YELLOW}stopped${NC}"
        port_info="-"
    else
        status="${RED}not found${NC}"
        port_info="-"
    fi

    printf "%-20s %-22b %-10s\n" "$name" "$status" "$port_info"
done

echo ""
echo -e "${BLUE}Active Containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | head -10

echo ""
echo -e "${BLUE}GPU Status:${NC}"
if command -v rocm-smi &> /dev/null; then
    rocm-smi --showuse 2>/dev/null | head -5 || echo "ROCm not responding"
else
    echo "rocm-smi not available on host"
fi

echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo "  Ollama API:  http://localhost:11434"
echo "  Open WebUI:  http://localhost:3000"
echo "  ComfyUI:     http://localhost:8188"
echo "  Whisper:     http://localhost:9000"
echo "  TTS:         http://localhost:8880"
