#!/bin/bash
# ============================================================
# Open WebUI Backup
# Backs up your Open WebUI data directory to a tar.gz archive
# Safe to run while Open WebUI is running
#
# Usage:
#   ./backup-openwebui.sh               → saves backup to current dir
#   ./backup-openwebui.sh /path/to/dir  → saves backup to custom dir
#
# Tip: Add to cron for automated backups:
#   0 2 * * * /path/to/backup-openwebui.sh /your/backup/dir
# ============================================================

set -e

# --- Auto-detect data directory ---
OWUI_BIN=$(which open-webui 2>/dev/null || find "$HOME" /opt -name "open-webui" -type f 2>/dev/null | head -1)

if [ -z "$OWUI_BIN" ]; then
    echo "✘ Could not find open-webui binary. Is it installed?"
    exit 1
fi

VENV=$(echo "$OWUI_BIN" | sed 's|/bin/open-webui||')
INSTALL_DIR=$(dirname "$VENV")

# Prefer DATA_DIR from systemd service if set, otherwise fall back to default
SERVICE=$(systemctl list-units --type=service 2>/dev/null | grep -i "openwebui\|open-webui" | awk '{print $1}' | head -1)
if [ -n "$SERVICE" ]; then
    SERVICE_DATA_DIR=$(sudo systemctl show "$SERVICE" -p Environment 2>/dev/null | grep -o 'DATA_DIR=[^ ]*' | cut -d= -f2)
fi

DATA_DIR="${SERVICE_DATA_DIR:-$INSTALL_DIR/data}"

# --- Backup destination ---
BACKUP_DEST="${1:-.}"
BACKUP_DEST=$(realpath "$BACKUP_DEST")
mkdir -p "$BACKUP_DEST"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DEST/openwebui-backup-$TIMESTAMP.tar.gz"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          Open WebUI Backup                       ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Data directory : $DATA_DIR"
echo "  Backup file    : $BACKUP_FILE"
echo ""

if [ ! -d "$DATA_DIR" ]; then
    echo "✘ Data directory not found: $DATA_DIR"
    exit 1
fi

echo "▶ Creating backup..."
tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "  ✔ Backup complete — $SIZE"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           ✅  Backup Complete!                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • File : $BACKUP_FILE"
echo "  • Size : $SIZE"
echo ""
echo "  To restore this backup, run:"
echo "    ./restore-openwebui.sh $BACKUP_FILE"
echo ""
