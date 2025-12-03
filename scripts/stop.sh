#!/bin/bash
# AMD AI Server Stack - Stop Services
# Usage: ./stop.sh [service|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

stop_ollama() {
    print_status "Stopping Ollama + Open WebUI..."
    cd "$REPO_DIR/stacks/ollama"
    docker compose down
}

stop_whisper() {
    print_status "Stopping Whisper STT..."
    cd "$REPO_DIR/stacks/whisper"
    docker compose down
}

stop_comfyui() {
    print_status "Stopping ComfyUI..."
    cd "$REPO_DIR/stacks/comfyui"
    docker compose down
}

stop_tts() {
    print_status "Stopping TTS service..."
    cd "$REPO_DIR/stacks/tts"
    docker compose down
}

stop_pytorch() {
    print_status "Stopping PyTorch environment..."
    cd "$REPO_DIR/stacks/pytorch"
    docker compose down
}

stop_all() {
    print_status "Stopping ALL services..."

    # Stop from main compose file
    cd "$REPO_DIR"
    docker compose down 2>/dev/null || true

    # Stop individual stacks
    for stack in ollama whisper comfyui tts pytorch; do
        if [[ -f "$REPO_DIR/stacks/$stack/docker-compose.yml" ]]; then
            cd "$REPO_DIR/stacks/$stack"
            docker compose down 2>/dev/null || true
        fi
    done

    print_status "All services stopped"
}

case "${1:-all}" in
    all)
        stop_all
        ;;
    ollama)
        stop_ollama
        ;;
    whisper|stt)
        stop_whisper
        ;;
    comfyui)
        stop_comfyui
        ;;
    tts)
        stop_tts
        ;;
    pytorch|dev)
        stop_pytorch
        ;;
    *)
        echo "Usage: $0 [service]"
        echo ""
        echo "Services:"
        echo "  all      - Stop all services (default)"
        echo "  ollama   - Ollama + Open WebUI"
        echo "  whisper  - Whisper STT"
        echo "  comfyui  - ComfyUI"
        echo "  tts      - Text-to-speech"
        echo "  pytorch  - PyTorch environment"
        exit 1
        ;;
esac
