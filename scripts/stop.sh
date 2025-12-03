#!/bin/bash
# AMD AI Server Stack - Stop Services
# Usage: ./stop.sh [service|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$REPO_DIR/docker-compose.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

stop_service() {
    local service="$1"
    print_status "Stopping $service..."
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" stop "$service"
}

stop_all() {
    print_status "Stopping ALL services..."
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" down
    print_status "All services stopped"
}

case "${1:-all}" in
    all|"")
        stop_all
        ;;
    ollama)
        stop_service ollama
        ;;
    whisper|stt)
        stop_service whisper
        ;;
    chatterbox|tts)
        stop_service chatterbox
        ;;
    comfyui|image)
        stop_service comfyui
        ;;
    control-panel|panel)
        stop_service control-panel
        ;;
    pytorch|dev)
        stop_service pytorch-rocm
        ;;
    *)
        echo "AMD AI Server Stack - Stop Script"
        echo ""
        echo "Usage: $0 [service]"
        echo ""
        echo "Services:"
        echo "  all         - Stop all services (default)"
        echo "  ollama      - Ollama LLM server"
        echo "  whisper     - Whisper STT"
        echo "  chatterbox  - Chatterbox TTS"
        echo "  comfyui     - ComfyUI image generation"
        echo "  control-panel - Control panel"
        echo "  pytorch     - PyTorch environment"
        exit 1
        ;;
esac
