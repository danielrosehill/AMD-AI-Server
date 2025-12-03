#!/bin/bash
# AMD AI Server Stack - Start Services
# Usage: ./start.sh [service|all|build]
# Examples:
#   ./start.sh           # Start all services
#   ./start.sh build     # Build and start all services
#   ./start.sh ollama    # Start only Ollama
#   ./start.sh whisper   # Start Whisper STT
#   ./start.sh chatterbox # Start Chatterbox TTS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$REPO_DIR/docker-compose.yml"

# Load environment
if [[ -f "$REPO_DIR/.env" ]]; then
    export $(grep -v '^#' "$REPO_DIR/.env" | xargs)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}Info:${NC} $1"
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

# Build all images that need building
build_images() {
    print_status "Building images (this may take a while on first run)..."
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" build
}

# Start specific service
start_service() {
    local service="$1"
    print_status "Starting $service..."
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" up -d "$service"
}

# Start all main services (excludes dev profile)
start_all() {
    print_status "Starting all services..."
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" up -d
}

# Build and start
build_and_start() {
    build_images
    start_all
}

# Print service URLs
print_urls() {
    echo ""
    echo -e "${GREEN}Service URLs:${NC}"
    echo "  Ollama API:      http://localhost:${OLLAMA_PORT:-11434}"
    echo "  Whisper STT:     http://localhost:${WHISPER_PORT:-9000}"
    echo "  Chatterbox TTS:  http://localhost:${TTS_PORT:-8880}"
    echo "  ComfyUI:         http://localhost:${COMFYUI_PORT:-8188}"
    echo "  Control Panel:   http://localhost:${CONTROL_PANEL_PORT:-8090}"
    echo ""
}

# Main
check_prerequisites
ensure_network

case "${1:-all}" in
    build)
        build_and_start
        print_urls
        ;;
    all|"")
        start_all
        print_urls
        ;;
    ollama)
        start_service ollama
        echo "  Ollama API: http://localhost:${OLLAMA_PORT:-11434}"
        ;;
    whisper|stt)
        start_service whisper
        echo "  Whisper STT: http://localhost:${WHISPER_PORT:-9000}"
        ;;
    chatterbox|tts)
        start_service chatterbox
        echo "  Chatterbox TTS: http://localhost:${TTS_PORT:-8880}"
        ;;
    comfyui|image)
        start_service comfyui
        echo "  ComfyUI: http://localhost:${COMFYUI_PORT:-8188}"
        ;;
    control-panel|panel)
        start_service control-panel
        echo "  Control Panel: http://localhost:${CONTROL_PANEL_PORT:-8090}"
        ;;
    pytorch|dev)
        print_status "Starting PyTorch ROCm environment (dev profile)..."
        cd "$REPO_DIR"
        docker compose -f "$COMPOSE_FILE" --profile dev up -d pytorch-rocm
        echo "  Access with: docker exec -it pytorch-rocm bash"
        ;;
    *)
        echo "AMD AI Server Stack - Start Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (none), all  - Start all services"
        echo "  build        - Build images and start all services"
        echo "  ollama       - Start Ollama LLM server"
        echo "  whisper      - Start Whisper STT"
        echo "  chatterbox   - Start Chatterbox TTS"
        echo "  comfyui      - Start ComfyUI image generation"
        echo "  control-panel- Start the control panel only"
        echo "  pytorch      - Start PyTorch dev environment"
        exit 1
        ;;
esac

echo ""
print_status "Run './scripts/status.sh' to check service status"
print_status "Run './scripts/check-gpu.sh' to verify GPU access"
