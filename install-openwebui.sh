#!/bin/bash
# ============================================================
# Open WebUI Installer
# Fresh install: Python venv, pip, data directory,
# and optional systemd service setup
#
# Usage:
#   ./install-openwebui.sh            → installs latest version
#   ./install-openwebui.sh 0.8.12     → installs specific version
# ============================================================

set -e

# --- Defaults ---
CURRENT_USER="${SUDO_USER:-$USER}"
HOME_DIR=$(eval echo "~$CURRENT_USER")
INSTALL_DIR="$HOME_DIR/openwebui"
VENV_DIR="$INSTALL_DIR/venv"
DATA_DIR="$INSTALL_DIR/data"
PORT=8080
SETUP_SERVICE=false

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
echo "║          Open WebUI Installer                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Install directory : $INSTALL_DIR"
echo "  Data directory    : $DATA_DIR"
echo "  Port              : $PORT"
echo "  Target version    : $TARGET_LABEL"
echo ""

# --- Check Python 3.11+ ---
echo "▶ Step 1: Checking Python version..."
PYTHON_BIN=$(which python3)
PYTHON_VERSION=$($PYTHON_BIN --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || [ "$PYTHON_MINOR" -lt 11 ]; then
    echo "  ✘ Python 3.11 or higher is required. Found: $PYTHON_VERSION"
    exit 1
fi
echo "  ✔ Python $PYTHON_VERSION found"

# --- Create install directory ---
echo ""
echo "▶ Step 2: Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
echo "  ✔ Install dir : $INSTALL_DIR"
echo "  ✔ Data dir    : $DATA_DIR"

# --- Create virtual environment ---
echo ""
echo "▶ Step 3: Creating virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "  ⚠ Venv already exists at $VENV_DIR — skipping creation"
else
    $PYTHON_BIN -m venv "$VENV_DIR"
    echo "  ✔ Venv created at: $VENV_DIR"
fi

# --- Install open-webui ---
echo ""
echo "▶ Step 4: Installing open-webui ($TARGET_LABEL)..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install $PIP_INSTALL_ARG --quiet

INSTALLED_VERSION=$(pip show open-webui | grep Version | awk '{print $2}')
echo "  ✔ Installed version: $INSTALLED_VERSION"

# --- Ask about systemd service ---
echo ""
read -p "  Would you like to set up a systemd service to run Open WebUI on boot? (y/N): " SETUP_SERVICE_INPUT
if [[ "$SETUP_SERVICE_INPUT" =~ ^[Yy]$ ]]; then
    SETUP_SERVICE=true
fi

if [ "$SETUP_SERVICE" = true ]; then
    echo ""
    echo "▶ Step 5: Setting up systemd service..."

    OWUI_BIN="$VENV_DIR/bin/open-webui"
    SERVICE_NAME="openwebui"
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Open WebUI
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment="DATA_DIR=$DATA_DIR"
ExecStart=$OWUI_BIN serve --host 0.0.0.0 --port $PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    sleep 3

    STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
    if [ "$STATUS" = "active" ]; then
        echo "  ✔ Service is running!"
    else
        echo "  ✘ Service did not start — check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
else
    echo ""
    echo "▶ Step 5: Skipping systemd setup."
    echo "  To start Open WebUI manually:"
    echo "    source $VENV_DIR/bin/activate"
    echo "    DATA_DIR=$DATA_DIR open-webui serve --host 0.0.0.0 --port $PORT"
fi

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         ✅  Installation Complete!               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • Installed version : $INSTALLED_VERSION"
echo "  • Venv              : $VENV_DIR"
echo "  • Data directory    : $DATA_DIR"
echo "  • Port              : $PORT"
echo ""
echo "  → Open http://$(hostname -I | awk '{print $1}'):$PORT in your browser"
echo "  → First time? Create an admin account on first visit."
echo ""
