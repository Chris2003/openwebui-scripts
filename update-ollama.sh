#!/bin/bash
# ============================================================
# Ollama Updater for bare Linux installs
# Updates the Ollama binary to the latest version
# Does NOT affect your models or configuration
#
# Usage:
#   ./update-ollama.sh
# ============================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          Ollama Updater                          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# --- Check Ollama is installed ---
if ! command -v ollama &>/dev/null; then
    echo "✘ Ollama not found. Install it first from https://ollama.com"
    exit 1
fi

CURRENT_VERSION=$(ollama --version 2>/dev/null | awk '{print $NF}')
echo "  Current version : $CURRENT_VERSION"

# --- Detect systemd service ---
SERVICE=""
if systemctl list-units --type=service 2>/dev/null | grep -q "ollama"; then
    SERVICE="ollama.service"
fi

# --- Stop Ollama service if running ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Stopping $SERVICE..."
    sudo systemctl stop "$SERVICE"
    echo "  ✔ Service stopped"
fi

# --- Run official Ollama install script (also serves as updater) ---
echo ""
echo "▶ Downloading and installing latest Ollama..."
curl -fsSL https://ollama.com/install.sh | sudo sh

NEW_VERSION=$(ollama --version 2>/dev/null | awk '{print $NF}')
echo "  ✔ Installed version: $NEW_VERSION"

# --- Restart service ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Starting $SERVICE..."
    sudo systemctl start "$SERVICE"
    sleep 2

    STATUS=$(sudo systemctl is-active "$SERVICE")
    if [ "$STATUS" = "active" ]; then
        echo "  ✔ Service is running!"
    else
        echo "  ✘ Service did not start — check logs with: sudo journalctl -u $SERVICE -n 50"
        exit 1
    fi
else
    echo ""
    echo "  ℹ No systemd service detected — start Ollama manually if needed."
fi

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          ✅  Ollama Updated!                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • Previous version : $CURRENT_VERSION"
echo "  • Installed version: $NEW_VERSION"
echo ""
echo "  Your models and configuration are unchanged."
echo ""
