#!/bin/bash
# AMD AI Server Stack - GPU Access Verification

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AMD AI Server Stack - GPU Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Host checks
echo -e "${BLUE}=== Host System ===${NC}"
echo ""

echo -e "GPU Device Nodes:"
if [[ -c /dev/kfd ]]; then
    echo -e "  /dev/kfd:          ${GREEN}present${NC}"
else
    echo -e "  /dev/kfd:          ${RED}missing${NC}"
fi

if [[ -c /dev/dri/renderD128 ]]; then
    echo -e "  /dev/dri/renderD128: ${GREEN}present${NC}"
else
    echo -e "  /dev/dri/renderD128: ${RED}missing${NC}"
fi
echo ""

echo -e "User Groups:"
if groups $USER | grep -q video; then
    echo -e "  video:  ${GREEN}yes${NC}"
else
    echo -e "  video:  ${RED}no${NC}"
fi
if groups $USER | grep -q render; then
    echo -e "  render: ${GREEN}yes${NC}"
else
    echo -e "  render: ${RED}no${NC}"
fi
echo ""

echo -e "ROCm on Host:"
if command -v rocm-smi &> /dev/null; then
    rocm-smi --showproductname 2>/dev/null || echo -e "  ${RED}rocm-smi failed${NC}"
else
    echo -e "  ${YELLOW}rocm-smi not installed on host${NC}"
fi
echo ""

# VRAM info from sysfs
if [[ -f /sys/class/drm/card0/device/mem_info_vram_total ]]; then
    vram_bytes=$(cat /sys/class/drm/card0/device/mem_info_vram_total)
    vram_gb=$(echo "scale=1; $vram_bytes / 1073741824" | bc)
    echo -e "VRAM Total: ${GREEN}${vram_gb} GB${NC}"
fi
if [[ -f /sys/class/drm/card0/device/mem_info_vram_used ]]; then
    vram_used=$(cat /sys/class/drm/card0/device/mem_info_vram_used)
    vram_used_gb=$(echo "scale=2; $vram_used / 1073741824" | bc)
    echo -e "VRAM Used:  ${vram_used_gb} GB"
fi
echo ""

# Container checks
echo -e "${BLUE}=== Container GPU Access ===${NC}"
echo ""

containers=(
    "ollama-rocm"
    "comfyui"
    "whisper-rocm"
    "pytorch-rocm"
)

for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "Container: ${GREEN}$container${NC}"

        # Check if rocm-smi works inside container
        if docker exec "$container" rocm-smi --showproductname 2>/dev/null; then
            echo -e "  GPU Access: ${GREEN}OK${NC}"
        elif docker exec "$container" python -c "import torch; print(f'PyTorch CUDA: {torch.cuda.is_available()}')" 2>/dev/null; then
            echo -e "  GPU Access: ${GREEN}OK (via PyTorch)${NC}"
        else
            echo -e "  GPU Access: ${YELLOW}unable to verify${NC}"
        fi

        # Check environment
        hsa_ver=$(docker exec "$container" printenv HSA_OVERRIDE_GFX_VERSION 2>/dev/null)
        if [[ -n "$hsa_ver" ]]; then
            echo -e "  HSA_OVERRIDE_GFX_VERSION: $hsa_ver"
        fi
        echo ""
    else
        echo -e "Container: ${YELLOW}$container${NC} (not running)"
        echo ""
    fi
done

echo -e "${BLUE}=== Quick PyTorch Test ===${NC}"
if docker ps --format '{{.Names}}' | grep -q "pytorch-rocm"; then
    echo "Running PyTorch GPU test..."
    docker exec pytorch-rocm python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device name: {torch.cuda.get_device_name(0)}')
    print(f'Device count: {torch.cuda.device_count()}')
" 2>/dev/null || echo -e "${RED}PyTorch test failed${NC}"
elif docker ps --format '{{.Names}}' | grep -q "ollama-rocm"; then
    echo "PyTorch container not running. Testing via Ollama..."
    docker exec ollama-rocm ls /dev/kfd 2>/dev/null && echo -e "  /dev/kfd: ${GREEN}accessible${NC}" || echo -e "  ${RED}/dev/kfd not accessible${NC}"
else
    echo -e "${YELLOW}No suitable container running for PyTorch test${NC}"
fi
