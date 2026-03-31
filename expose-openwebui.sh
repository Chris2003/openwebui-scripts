#!/bin/bash
# ============================================================
# Open WebUI Network Expose
# Makes Open WebUI accessible to anyone on your local network
#
# What it does:
#   1. Ensures Open WebUI binds to 0.0.0.0 (all interfaces)
#   2. Opens the port in UFW firewall if active
#   3. Prints the local IP so you can share it
#
# Usage:
#   ./expose-openwebui.sh           → uses default port 8080
#   ./expose-openwebui.sh 9090      → uses custom port
# ============================================================

set -e

# --- Auto-detect ---
OWUI_BIN=$(which open-webui 2>/dev/null || find "$HOME" /opt -name "open-webui" -type f 2>/dev/null | head -1)

if [ -z "$OWUI_BIN" ]; then
    echo "✘ Could not find open-webui binary. Is it installed?"
    exit 1
fi

SERVICE=$(systemctl list-units --type=service 2>/dev/null | grep -i "openwebui\|open-webui" | awk '{print $1}' | head -1)
SERVICE_FILE="/etc/systemd/system/$SERVICE"

# --- Port ---
PORT="${1:-8080}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║       Open WebUI Network Expose                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# --- Step 1: Check/fix host binding ---
echo "▶ Step 1: Checking host binding..."

if [ -n "$SERVICE" ] && [ -f "$SERVICE_FILE" ]; then
    CURRENT_EXEC=$(grep "ExecStart" "$SERVICE_FILE")

    if echo "$CURRENT_EXEC" | grep -q "\-\-host 0.0.0.0"; then
        echo "  ✔ Already bound to 0.0.0.0 — no changes needed"
    elif echo "$CURRENT_EXEC" | grep -q "\-\-host 127.0.0.1"; then
        echo "  ⚠ Currently bound to 127.0.0.1 — updating to 0.0.0.0..."
        sudo sed -i 's/--host 127.0.0.1/--host 0.0.0.0/g' "$SERVICE_FILE"
        echo "  ✔ Updated to 0.0.0.0"
    else
        # No --host flag at all, append it
        echo "  ⚠ No --host flag found — adding --host 0.0.0.0..."
        sudo sed -i "s|open-webui serve|open-webui serve --host 0.0.0.0|g" "$SERVICE_FILE"
        echo "  ✔ Added --host 0.0.0.0"
    fi

    # Also ensure port is set
    if ! echo "$CURRENT_EXEC" | grep -q "\-\-port"; then
        sudo sed -i "s|--host 0.0.0.0|--host 0.0.0.0 --port $PORT|g" "$SERVICE_FILE"
        echo "  ✔ Added --port $PORT"
    fi

    sudo systemctl daemon-reload
else
    echo "  ⚠ No systemd service detected."
    echo "  When starting Open WebUI manually, use:"
    echo "    open-webui serve --host 0.0.0.0 --port $PORT"
fi

# --- Step 2: Open firewall port ---
echo ""
echo "▶ Step 2: Checking firewall (UFW)..."

if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status | head -1)

    if echo "$UFW_STATUS" | grep -q "inactive"; then
        echo "  ℹ UFW is inactive — no firewall rules needed"
    else
        if sudo ufw status | grep -q "$PORT"; then
            echo "  ✔ Port $PORT is already open in UFW"
        else
            echo "  ⚠ Port $PORT is not open — adding UFW rule..."
            sudo ufw allow "$PORT/tcp" comment "Open WebUI"
            echo "  ✔ Port $PORT opened in UFW"
        fi
    fi
else
    echo "  ℹ UFW not installed — skipping firewall step"
    echo "  If you use iptables or another firewall, make sure port $PORT is open."
fi

# --- Step 3: Restart service ---
if [ -n "$SERVICE" ]; then
    echo ""
    echo "▶ Step 3: Restarting $SERVICE..."
    sudo systemctl restart "$SERVICE"
    sleep 3

    STATUS=$(sudo systemctl is-active "$SERVICE")
    if [ "$STATUS" = "active" ]; then
        echo "  ✔ Service is running!"
    else
        echo "  ✘ Service did not start — check logs with: sudo journalctl -u $SERVICE -n 50"
        exit 1
    fi
fi

# --- Get local IPs ---
LOCAL_IPS=$(hostname -I | tr ' ' '\n' | grep -v '^$' | grep -v '^::')

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅  Open WebUI is Network-Accessible!     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Anyone on your local network can now connect at:"
echo ""
while IFS= read -r IP; do
    echo "    → http://$IP:$PORT"
done <<< "$LOCAL_IPS"
echo ""
echo "  This machine only:"
echo "    → http://localhost:$PORT"
echo ""
echo "  ⚠ Note: This exposes Open WebUI to your local network."
echo "    Do not expose port $PORT to the internet unless you"
echo "    have authentication and HTTPS configured."
echo ""
