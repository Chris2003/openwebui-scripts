#!/bin/bash
# ============================================================
# Open WebUI systemd Service Setup
# Sets up Open WebUI to run as a systemd service on boot
#
# Usage:
#   ./setup-openwebui-service.sh
# ============================================================

set -e  # Exit immediately on any error

# --- Auto-detect the open-webui binary ---
OWUI_BIN=$(which open-webui 2>/dev/null || find "$HOME" /opt -name "open-webui" -type f 2>/dev/null | head -1)

if [ -z "$OWUI_BIN" ]; then
    echo "✘ Could not find the open-webui binary."
    echo "  Make sure open-webui is installed and your venv is activated."
    exit 1
fi

VENV=$(echo "$OWUI_BIN" | sed 's|/bin/open-webui||')
INSTALL_DIR=$(dirname "$VENV")
CURRENT_USER="${SUDO_USER:-$USER}"
DATA_DIR="$INSTALL_DIR/data"
SERVICE_NAME="openwebui"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
PORT=8080

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║      Open WebUI Service Setup                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Detected user    : $CURRENT_USER"
echo "  Detected venv    : $VENV"
echo "  Install dir      : $INSTALL_DIR"
echo "  Data directory   : $DATA_DIR"
echo "  Port             : $PORT"
echo ""

# --- Check if service already exists ---
if [ -f "$SERVICE_FILE" ]; then
    echo "⚠ Service file already exists at $SERVICE_FILE"
    read -p "  Overwrite it? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "  Aborted."
        exit 0
    fi
fi

# --- Create data directory ---
echo "▶ Step 1: Creating data directory..."
mkdir -p "$DATA_DIR"
echo "  ✔ Data directory ready: $DATA_DIR"

# --- Write systemd service file ---
echo ""
echo "▶ Step 2: Writing systemd service file..."

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

echo "  ✔ Service file written to: $SERVICE_FILE"

# --- Enable and start the service ---
echo ""
echo "▶ Step 3: Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
sleep 3

STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
if [ "$STATUS" = "active" ]; then
    echo "  ✔ Service is running!"
else
    echo "  ✘ Service did not start — checking logs..."
    sudo journalctl -u "$SERVICE_NAME" -n 30 --no-pager
    exit 1
fi

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅  Service Setup Complete!               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  • Service name   : $SERVICE_NAME.service"
echo "  • Status         : $STATUS"
echo "  • Runs as user   : $CURRENT_USER"
echo "  • Data directory : $DATA_DIR"
echo "  • Port           : $PORT"
echo ""
echo "  Useful commands:"
echo "    sudo systemctl status $SERVICE_NAME"
echo "    sudo systemctl restart $SERVICE_NAME"
echo "    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "  → Open http://$(hostname -I | awk '{print $1}'):$PORT in your browser"
echo ""
