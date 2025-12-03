#!/bin/bash
# AMD AI Server Stack - Start Services
# Usage: ./start.sh [service|all]
# Examples:
#   ./start.sh           # Start core services (ollama, open-webui, comfyui)
#   ./start.sh all       # Start all services including dev
#   ./start.sh ollama    # Start only Ollama stack
#   ./start.sh whisper   # Start Whisper STT
#   ./start.sh tts       # Start TTS service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [[ -f "$REPO_DIR/.env" ]]; then
    export $(grep -v '^#' "$REPO_DIR/.env" | xargs)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi

    # Check GPU devices
    if [[ ! -c /dev/kfd ]]; then
        print_warning "/dev/kfd not found. ROCm GPU access may not work."
    fi

    if [[ ! -c /dev/dri/renderD128 ]]; then
        print_warning "/dev/dri/renderD128 not found. GPU access may not work."
    fi
}

# Create network if it doesn't exist
ensure_network() {
    local network="${DOCKER_NETWORK:-ai-stack}"
    if ! docker network inspect "$network" &> /dev/null; then
        print_status "Creating Docker network: $network"
        docker network create "$network"
    fi
}

start_ollama() {
    print_status "Starting Ollama + Open WebUI..."
    cd "$REPO_DIR/stacks/ollama"
    docker compose up -d
    echo ""
    echo "Access points:"
    echo "  Ollama API:  http://localhost:${OLLAMA_PORT:-11434}"
    echo "  Open WebUI:  http://localhost:${OPENWEBUI_PORT:-3000}"
}

start_whisper() {
    print_status "Starting Whisper STT..."
    cd "$REPO_DIR/stacks/whisper"
    docker compose up -d --build
    echo ""
    echo "Access points:"
    echo "  Whisper API: http://localhost:${WHISPER_PORT:-9000}"
}

start_comfyui() {
    print_status "Starting ComfyUI..."
    cd "$REPO_DIR/stacks/comfyui"
    docker compose up -d
    echo ""
    echo "Access points:"
    echo "  ComfyUI:     http://localhost:${COMFYUI_PORT:-8188}"
}

start_tts() {
    print_status "Starting TTS service..."
    cd "$REPO_DIR/stacks/tts"
    docker compose up -d
    echo ""
    echo "Access points:"
    echo "  TTS API:     http://localhost:${TTS_PORT:-8880}"
}

start_pytorch() {
    print_status "Starting PyTorch ROCm environment..."
    cd "$REPO_DIR/stacks/pytorch"
    docker compose up -d
    echo ""
    echo "PyTorch container started. Access with:"
    echo "  docker exec -it pytorch-rocm bash"
}

start_core() {
    print_status "Starting core services..."
    cd "$REPO_DIR"
    docker compose up -d ollama open-webui comfyui
    echo ""
    echo "Core services started:"
    echo "  Ollama API:  http://localhost:${OLLAMA_PORT:-11434}"
    echo "  Open WebUI:  http://localhost:${OPENWEBUI_PORT:-3000}"
    echo "  ComfyUI:     http://localhost:${COMFYUI_PORT:-8188}"
}

start_all() {
    print_status "Starting ALL services..."
    ensure_network
    start_ollama
    echo ""
    start_whisper
    echo ""
    start_comfyui
    echo ""
    start_tts
    echo ""
    print_status "All services started!"
}

# Main
check_prerequisites

case "${1:-core}" in
    all)
        start_all
        ;;
    ollama)
        ensure_network
        start_ollama
        ;;
    whisper|stt)
        ensure_network
        start_whisper
        ;;
    comfyui)
        ensure_network
        start_comfyui
        ;;
    tts)
        ensure_network
        start_tts
        ;;
    pytorch|dev)
        ensure_network
        start_pytorch
        ;;
    core|"")
        start_core
        ;;
    *)
        echo "Usage: $0 [service]"
        echo ""
        echo "Services:"
        echo "  core     - Ollama, Open WebUI, ComfyUI (default)"
        echo "  all      - All services"
        echo "  ollama   - Ollama + Open WebUI"
        echo "  whisper  - Whisper STT"
        echo "  comfyui  - ComfyUI image generation"
        echo "  tts      - Text-to-speech"
        echo "  pytorch  - PyTorch ROCm dev environment"
        exit 1
        ;;
esac

echo ""
print_status "Run './scripts/status.sh' to check service status"
print_status "Run './scripts/check-gpu.sh' to verify GPU access"
