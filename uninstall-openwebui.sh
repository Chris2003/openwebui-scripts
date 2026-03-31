#!/bin/bash
# ============================================================
# Open WebUI Uninstaller
# Cleanly removes Open WebUI from your system
# Optionally keeps or wipes your data
#
# Usage:
#   ./uninstall-openwebui.sh
# ============================================================

set -e

# --- Auto-detect ---
OWUI_BIN=$(which open-webui 2>/dev/null || find "$HOME" /opt -name "open-webui" -type f 2>/dev/null | head -1)

if [ -z "$OWUI_BIN" ]; then
    echo "✘ Could not find open-webui binary. Is it installed?"
    exit 1
fi

VENV=$(echo "$OWUI_BIN" | sed 's|/bin/open-webui||')
INSTALL_DIR=$(dirname "$VENV")

SERVICE=$(systemctl list-units --type=service 2>/dev/null | grep -i "openwebui\|open-webui" | awk '{print $1}' | head -1)
if [ -n "$SERVICE" ]; then
    SERVICE_DATA_DIR=$(sudo systemctl show "$SERVICE" -p Environment 2>/dev/null | grep -o 'DATA_DIR=[^ ]*' | cut -d= -f2)
    SERVICE_FILE="/etc/systemd/system/$SERVICE"
fi

DATA_DIR="${SERVICE_DATA_DIR:-$INSTALL_DIR/data}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          Open WebUI Uninstaller                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Install directory : $INSTALL_DIR"
echo "  Data directory    : $DATA_DIR"
[ -n "$SERVICE" ] && echo "  Service           : $SERVICE"
echo ""
echo "  ⚠ WARNING: This will remove Open WebUI from your system."
read -p "  Are you sure you want to continue? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

# --- Ask about data ---
echo ""
read -p "  Do you want to keep your data (chats, users, uploads)? (Y/n): " KEEP_DATA
if [[ "$KEEP_DATA" =~ ^[Nn]$ ]]; then
    WIPE_DATA=true
else
    WIPE_DATA=false
fi

# --- Backup data before wiping ---
if [ "$WIPE_DATA" = true ] && [ -d "$DATA_DIR" ]; then
    BACKUP_FILE="$HOME/openwebui-final-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo ""
    echo "▶ Creating final backup before wipe..."
    tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
    echo "  ✔ Final backup saved to: $BACKUP_FILE"
fi

# --- Stop and disable service ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Stopping and disabling $SERVICE..."
    sudo systemctl stop "$SERVICE" 2>/dev/null || true
    sudo systemctl disable "$SERVICE" 2>/dev/null || true

    if [ -f "$SERVICE_FILE" ]; then
        sudo rm -f "$SERVICE_FILE"
        echo "  ✔ Service file removed: $SERVICE_FILE"
    fi

    sudo systemctl daemon-reload
    echo "  ✔ Service removed"
fi

# --- Remove venv ---
echo ""
echo "▶ Removing virtual environment..."
rm -rf "$VENV"
echo "  ✔ Venv removed: $VENV"

# --- Wipe or keep data ---
if [ "$WIPE_DATA" = true ]; then
    echo ""
    echo "▶ Removing data directory..."
    rm -rf "$DATA_DIR"
    echo "  ✔ Data removed: $DATA_DIR"

    # Remove install dir if empty
    rmdir "$INSTALL_DIR" 2>/dev/null && echo "  ✔ Install directory removed: $INSTALL_DIR" || true
else
    echo ""
    echo "  ℹ Data kept at: $DATA_DIR"
fi

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         ✅  Uninstall Complete!                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
if [ "$WIPE_DATA" = true ]; then
    echo "  Open WebUI and all data have been removed."
    [ -n "$BACKUP_FILE" ] && echo "  • Final backup : $BACKUP_FILE"
else
    echo "  Open WebUI has been removed. Your data is kept at:"
    echo "  • $DATA_DIR"
    echo ""
    echo "  To reinstall later, run: ./install-openwebui.sh"
fi
echo ""
