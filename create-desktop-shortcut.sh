#!/bin/bash
# ============================================================
# Open WebUI Desktop Shortcut Creator
# Creates a desktop icon that starts the service if needed
# and opens Open WebUI in your browser with one click
#
# Usage:
#   ./create-desktop-shortcut.sh           → default port 8080
#   ./create-desktop-shortcut.sh 9090      → custom port
# ============================================================

set -e

CURRENT_USER="${SUDO_USER:-$USER}"
HOME_DIR=$(eval echo "~$CURRENT_USER")
PORT="${1:-8080}"
DESKTOP_DIR="$HOME_DIR/Desktop"
LAUNCHER="$HOME_DIR/openwebui/launch-openwebui.sh"
DESKTOP_FILE="$DESKTOP_DIR/OpenWebUI.desktop"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     Open WebUI Desktop Shortcut Creator          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# --- Detect service name ---
SERVICE=$(systemctl list-units --type=service 2>/dev/null | grep -i "openwebui\|open-webui" | awk '{print $1}' | head -1)

if [ -z "$SERVICE" ]; then
    echo "  ⚠ No openwebui systemd service detected."
    echo "  The shortcut will open the browser directly without starting a service."
    echo "  Make sure Open WebUI is already running when you use the shortcut."
    USE_SERVICE=false
else
    echo "  Detected service : $SERVICE"
    USE_SERVICE=true
fi

echo "  Port             : $PORT"
echo "  Launcher script  : $LAUNCHER"
echo "  Desktop file     : $DESKTOP_FILE"
echo ""

# --- Create Desktop dir if missing ---
mkdir -p "$DESKTOP_DIR"
mkdir -p "$(dirname "$LAUNCHER")"

# --- Create launcher script ---
echo "▶ Creating launcher script..."

if [ "$USE_SERVICE" = true ]; then
    cat > "$LAUNCHER" <<LAUNCHER
#!/bin/bash
# Open WebUI Launcher
# Starts the service if not running, then opens the browser

SERVICE="$SERVICE"
PORT="$PORT"
URL="http://localhost:\$PORT"

# Start service if not active
if ! systemctl is-active --quiet "\$SERVICE"; then
    echo "Starting Open WebUI service..."
    sudo systemctl start "\$SERVICE"

    # Wait up to 15 seconds for it to be ready
    for i in \$(seq 1 15); do
        sleep 1
        if curl -s "\$URL" > /dev/null 2>&1; then
            break
        fi
    done
fi

# Open browser
xdg-open "\$URL"
LAUNCHER
else
    cat > "$LAUNCHER" <<LAUNCHER
#!/bin/bash
xdg-open "http://localhost:$PORT"
LAUNCHER
fi

chmod +x "$LAUNCHER"
# Make sure the launcher is owned by the real user, not root
chown "$CURRENT_USER:$CURRENT_USER" "$LAUNCHER"
echo "  ✔ Launcher script created"

# --- Create .desktop file ---
echo "▶ Creating desktop shortcut..."

cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Open WebUI
Comment=Launch Open WebUI AI Interface
Exec=bash -c '$LAUNCHER'
Icon=applications-science
Terminal=false
Categories=Network;AI;
DESKTOP

chmod +x "$DESKTOP_FILE"
chown "$CURRENT_USER:$CURRENT_USER" "$DESKTOP_FILE"

# Trust the .desktop file on GNOME so it's clickable without prompts
gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true

echo "  ✔ Desktop shortcut created"

# --- Done ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅  Shortcut Created!                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  You should now see an 'Open WebUI' icon on your desktop."
echo "  Click it to start Open WebUI and open it in your browser."
echo ""
echo "  ℹ If the icon shows as untrusted, right-click it and"
echo "    select 'Allow Launching'."
echo ""
