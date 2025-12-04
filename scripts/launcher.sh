#!/bin/bash
# AMD AI Server Launcher - For desktop menu entry
# Starts services if not running, then opens control panel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Check if control panel is running
if ! curl -s http://localhost:8090 > /dev/null 2>&1; then
    # Start services
    "$SCRIPT_DIR/start.sh" > /tmp/amd-ai-server-start.log 2>&1
    
    # Wait for control panel to be ready (up to 30 seconds)
    for i in {1..30}; do
        if curl -s http://localhost:8090 > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

# Open control panel in browser
xdg-open http://localhost:8090
