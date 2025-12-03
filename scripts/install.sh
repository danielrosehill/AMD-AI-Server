#!/bin/bash
# AMD AI Server - Installation Script
# Installs systemd service and desktop menu entry

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "AMD AI Server - Installation"
echo "============================"
echo ""

# Check if running as root (we need sudo for systemd)
if [[ $EUID -eq 0 ]]; then
    echo "Please run this script as a normal user (not root)."
    echo "Sudo will be requested when needed."
    exit 1
fi

# Verify docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Verify docker compose is available
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose (v2) is not available"
    exit 1
fi

echo "Repository location: $REPO_DIR"
echo ""

# Install systemd service
echo "Installing systemd service..."
sudo cp "$REPO_DIR/systemd/amd-ai-server.service" /etc/systemd/system/
sudo systemctl daemon-reload

echo ""
echo "Do you want to enable autostart on boot? [Y/n]"
read -r response
if [[ ! "$response" =~ ^[Nn]$ ]]; then
    sudo systemctl enable amd-ai-server.service
    echo "Autostart enabled."
else
    echo "Autostart skipped. Enable later with: sudo systemctl enable amd-ai-server.service"
fi

# Install desktop entry
echo ""
echo "Installing desktop menu entry..."
mkdir -p ~/.local/share/applications
cp "$REPO_DIR/desktop/amd-ai-server.desktop" ~/.local/share/applications/

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
fi

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  Start stack:    sudo systemctl start amd-ai-server"
echo "  Stop stack:     sudo systemctl stop amd-ai-server"
echo "  View status:    sudo systemctl status amd-ai-server"
echo "  View logs:      docker compose -f $REPO_DIR/docker-compose.yml logs -f"
echo ""
echo "The 'AMD AI Server' entry should now appear in your application menu."
echo "Control panel will be available at: http://localhost:8090"
