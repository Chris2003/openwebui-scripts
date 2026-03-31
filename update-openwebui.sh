#!/bin/bash
# ============================================================
# Open WebUI Safe Updater
# Supports pip + venv installs on Ubuntu/Linux
#
# Usage:
#   ./update-openwebui.sh            → installs latest version
#   ./update-openwebui.sh 0.8.12     → installs specific version
# ============================================================

set -e  # Exit immediately on any error

# --- Auto-detect venv by finding the open-webui binary ---
OWUI_BIN=$(which open-webui 2>/dev/null || find "$HOME" /opt -name "open-webui" -type f 2>/dev/null | head -1)

if [ -z "$OWUI_BIN" ]; then
    echo "✘ Could not find the open-webui binary."
    echo "  Make sure your virtual environment is activated or open-webui is in your PATH."
    exit 1
fi

VENV=$(echo "$OWUI_BIN" | sed 's|/bin/open-webui||')
INSTALL_DIR=$(dirname "$VENV")

# Auto-detect Python version inside venv
PYTHON_VERSION=$(ls "$VENV/lib/" | grep "python" | head -1)

DATA_SRC="$VENV/lib/$PYTHON_VERSION/site-packages/open_webui/data/webui.db"
DATA_DIR="$INSTALL_DIR/data"
BACKUP_DIR="$INSTALL_DIR"

# --- Version argument ---
if [ -n "$1" ]; then
    PIP_INSTALL_ARG="open-webui==$1"
    TARGET_LABEL="$1"
else
    PIP_INSTALL_ARG="open-webui"
    TARGET_LABEL="latest"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║          Open WebUI Safe Updater                 ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Detected venv   : $VENV"
echo "  Target version  : $TARGET_LABEL"
echo ""

# --- Step 1: Backup existing database ---
echo "▶ Step 1: Backing up database..."
BACKUP_FILE=""
mkdir -p "$DATA_DIR"

if [ -f "$DATA_DIR/webui.db" ]; then
    BACKUP_FILE="$BACKUP_DIR/webui.db.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$DATA_DIR/webui.db" "$BACKUP_FILE"
    echo "  ✔ Backup saved to: $BACKUP_FILE"
elif [ -f "$DATA_SRC" ]; then
    BACKUP_FILE="$BACKUP_DIR/webui.db.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$DATA_SRC" "$BACKUP_FILE"
    # Also migrate it to the safe data dir
    cp "$DATA_SRC" "$DATA_DIR/webui.db"
    echo "  ✔ Backup saved to: $BACKUP_FILE"
    echo "  ✔ Database migrated to: $DATA_DIR/webui.db"
else
    echo "  ⚠ No webui.db found — skipping backup"
fi

# --- Step 2: Set DATA_DIR env var so open-webui uses the safe location ---
export DATA_DIR="$DATA_DIR"

# --- Step 3: Upgrade open-webui ---
echo ""
echo "▶ Step 2: Upgrading open-webui ($TARGET_LABEL)..."
source "$VENV/bin/activate"
pip install --upgrade $PIP_INSTALL_ARG --quiet

INSTALLED_VERSION=$(pip show open-webui | grep Version | awk '{print $2}')
echo "  ✔ Installed version: $INSTALLED_VERSION"

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║           ✅  Update Complete!                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • Installed version : $INSTALLED_VERSION"
echo "  • Data directory    : $DATA_DIR"
[ -n "$BACKUP_FILE" ] && echo "  • Backup file       : $BACKUP_FILE"
echo ""
echo "  ⚠ Remember to restart Open WebUI for changes to take effect."
echo ""
