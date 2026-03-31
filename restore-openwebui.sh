#!/bin/bash
# ============================================================
# Open WebUI Restore
# Restores a backup created by backup-openwebui.sh
#
# Usage:
#   ./restore-openwebui.sh /path/to/openwebui-backup-TIMESTAMP.tar.gz
# ============================================================

set -e

# --- Check argument ---
if [ -z "$1" ]; then
    echo ""
    echo "Usage: ./restore-openwebui.sh /path/to/openwebui-backup-TIMESTAMP.tar.gz"
    echo ""
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "✘ Backup file not found: $BACKUP_FILE"
    exit 1
fi

# --- Auto-detect install and data directory ---
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
fi

DATA_DIR="${SERVICE_DATA_DIR:-$INSTALL_DIR/data}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          Open WebUI Restore                      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Backup file    : $BACKUP_FILE"
echo "  Data directory : $DATA_DIR"
echo ""
echo "  ⚠ WARNING: This will overwrite your current data."
read -p "  Are you sure you want to continue? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

# --- Stop service if running ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Stopping $SERVICE..."
    sudo systemctl stop "$SERVICE"
    echo "  ✔ Service stopped"
fi

# --- Backup current data before restoring ---
if [ -d "$DATA_DIR" ]; then
    PRE_RESTORE_BACKUP="$INSTALL_DIR/openwebui-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo ""
    echo "▶ Saving current data as pre-restore backup..."
    tar -czf "$PRE_RESTORE_BACKUP" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
    echo "  ✔ Pre-restore backup saved to: $PRE_RESTORE_BACKUP"
fi

# --- Restore ---
echo ""
echo "▶ Restoring from backup..."
rm -rf "$DATA_DIR"
mkdir -p "$(dirname "$DATA_DIR")"
tar -xzf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")"
echo "  ✔ Data restored to: $DATA_DIR"

# --- Restart service if it was running ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Starting $SERVICE..."
    sudo systemctl start "$SERVICE"
    sleep 3

    STATUS=$(sudo systemctl is-active "$SERVICE")
    if [ "$STATUS" = "active" ]; then
        echo "  ✔ Service is running!"
    else
        echo "  ✘ Service did not start — check logs with: sudo journalctl -u $SERVICE -n 50"
        exit 1
    fi
else
    echo ""
    echo "  ℹ No systemd service detected — start Open WebUI manually."
fi

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          ✅  Restore Complete!                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • Restored from : $BACKUP_FILE"
echo "  • Data dir      : $DATA_DIR"
[ -n "$PRE_RESTORE_BACKUP" ] && echo "  • Pre-restore backup : $PRE_RESTORE_BACKUP"
echo ""
