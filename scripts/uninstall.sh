#!/bin/bash
# AMD AI Server - Uninstallation Script
# Removes systemd service and desktop menu entry

set -e

echo "AMD AI Server - Uninstallation"
echo "=============================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Please run this script as a normal user (not root)."
    echo "Sudo will be requested when needed."
    exit 1
fi

# Stop and disable systemd service if it exists
if [[ -f /etc/systemd/system/amd-ai-server.service ]]; then
    echo "Stopping and removing systemd service..."
    sudo systemctl stop amd-ai-server.service 2>/dev/null || true
    sudo systemctl disable amd-ai-server.service 2>/dev/null || true
    sudo rm /etc/systemd/system/amd-ai-server.service
    sudo systemctl daemon-reload
    echo "Systemd service removed."
else
    echo "Systemd service not found, skipping."
fi

# Remove desktop entry
if [[ -f ~/.local/share/applications/amd-ai-server.desktop ]]; then
    echo "Removing desktop menu entry..."
    rm ~/.local/share/applications/amd-ai-server.desktop
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    echo "Desktop entry removed."
else
    echo "Desktop entry not found, skipping."
fi

echo ""
echo "Uninstallation complete."
echo ""
echo "Note: Docker containers and images have NOT been removed."
echo "To fully clean up, run:"
echo "  docker compose down"
echo "  docker compose down --rmi all  # to also remove images"
