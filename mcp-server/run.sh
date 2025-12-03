#!/bin/bash
# Run the Local AI MCP Server

# Configuration - adjust these if your services are on different ports
export WHISPER_URL="${WHISPER_URL:-http://localhost:9000}"
export OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate venv if it exists
if [ -d "$SCRIPT_DIR/.venv" ]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

# Run the server
python -m local_ai_mcp.server
