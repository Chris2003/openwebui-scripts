#!/bin/bash
# ============================================================
# Open WebUI Installer
# Installs Open WebUI directly on the system in a Python venv
# No Docker required
#
# Usage:
#   ./install-openwebui.sh            → installs latest version
#   ./install-openwebui.sh 0.8.12     → installs specific version
# ============================================================

set -e

# --- Resolve real user (safe with or without sudo) ---
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
echo "║          Native Linux — pip + venv               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Install directory : $INSTALL_DIR"
echo "  Data directory    : $DATA_DIR"
echo "  Port              : $PORT"
echo "  Target version    : $TARGET_LABEL"
echo ""

# --- Step 1: Find best compatible Python ---
# open-webui requires Python >= 3.11 and < 3.13
echo "▶ Step 1: Finding compatible Python version..."
PYTHON_BIN=""

for candidate in python3.12 python3.11 python3; do
    if command -v "$candidate" &>/dev/null; then
        VER=$("$candidate" --version 2>&1 | awk '{print $2}')
        MAJOR=$(echo "$VER" | cut -d. -f1)
        MINOR=$(echo "$VER" | cut -d. -f2)

        if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 11 ] && [ "$MINOR" -lt 13 ]; then
            PYTHON_BIN=$(which "$candidate")
            PYTHON_VERSION="$VER"
            echo "  ✔ Using Python $PYTHON_VERSION ($PYTHON_BIN)"
            break
        else
            echo "  ℹ $candidate $VER — not compatible (need 3.11–3.12), skipping"
        fi
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo ""
    echo "  ✘ No compatible Python found (requires 3.11 or 3.12)."
    echo "  Your system Python is too new for open-webui."
    echo ""
    echo "  pyenv will be used to install Python 3.12 only for this venv."
    echo "  It will NOT affect your system Python in any way."
    echo ""
    read -p "  Would you like to install Python 3.12 via pyenv (isolated, no system changes)? (y/N): " INSTALL_PYTHON
    if [[ "$INSTALL_PYTHON" =~ ^[Yy]$ ]]; then
        echo ""

        # Install pyenv build dependencies (system libs only, no Python)
        echo "  Installing pyenv build dependencies..."
        sudo apt-get update -qq
        sudo apt-get install -y --quiet \
            build-essential libssl-dev zlib1g-dev libbz2-dev \
            libreadline-dev libsqlite3-dev curl libncursesw5-dev \
            xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

        # Install pyenv into the user home (no sudo needed, no system changes)
        if [ ! -d "$HOME_DIR/.pyenv" ]; then
            echo "  Installing pyenv into $HOME_DIR/.pyenv ..."
            curl -fsSL https://pyenv.run | bash
        else
            echo "  ✔ pyenv already installed at $HOME_DIR/.pyenv"
        fi

        export PYENV_ROOT="$HOME_DIR/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"

        # Install Python 3.12 via pyenv (goes to ~/.pyenv/versions/3.12.x)
        echo "  Installing Python 3.12 via pyenv (this may take a few minutes)..."
        pyenv install -s 3.12
        pyenv shell 3.12

        PYTHON_BIN="$PYENV_ROOT/versions/$(pyenv version-name)/bin/python3"
        PYTHON_VERSION=$("$PYTHON_BIN" --version 2>&1 | awk '{print $2}')
        echo "  ✔ Python $PYTHON_VERSION ready (isolated to pyenv, not system-wide)"
    else
        echo "  Aborted."
        echo ""
        echo "  If you want to install manually:"
        echo "    curl https://pyenv.run | bash"
        echo "    pyenv install 3.12"
        exit 1
    fi
fi

# --- Step 2: Install system dependencies ---
echo ""
echo "▶ Step 2: Installing system dependencies..."
sudo apt-get install -y python3-venv python3-pip ffmpeg libsm6 libxext6 --quiet
echo "  ✔ Dependencies installed"

# --- Step 3: Create directories ---
echo ""
echo "▶ Step 3: Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
echo "  ✔ Install dir : $INSTALL_DIR"
echo "  ✔ Data dir    : $DATA_DIR"

# --- Step 4: Create virtual environment ---
echo ""
echo "▶ Step 4: Creating virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "  ⚠ Venv already exists at $VENV_DIR — skipping creation"
else
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    echo "  ✔ Venv created at: $VENV_DIR"
fi

# --- Step 5: Install open-webui ---
echo ""
echo "▶ Step 5: Installing open-webui ($TARGET_LABEL)..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install $PIP_INSTALL_ARG --quiet

INSTALLED_VERSION=$(pip show open-webui | grep Version | awk '{print $2}')
echo "  ✔ Installed version: $INSTALLED_VERSION"

# --- Step 6: Ask about systemd service ---
echo ""
read -p "  Would you like to set up a systemd service to run Open WebUI on boot? (y/N): " SETUP_SERVICE_INPUT
if [[ "$SETUP_SERVICE_INPUT" =~ ^[Yy]$ ]]; then
    SETUP_SERVICE=true
fi

if [ "$SETUP_SERVICE" = true ]; then
    echo ""
    echo "▶ Step 6: Setting up systemd service..."

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

    # --- Step 7: Create desktop shortcut ---
    echo ""
    read -p "  Would you like a desktop shortcut to launch Open WebUI in your browser? (y/N): " SETUP_SHORTCUT
    if [[ "$SETUP_SHORTCUT" =~ ^[Yy]$ ]]; then
        LAUNCHER="$HOME_DIR/openwebui/launch-openwebui.sh"
        DESKTOP_FILE="$HOME_DIR/Desktop/OpenWebUI.desktop"

        cat > "$LAUNCHER" <<LAUNCHER
#!/bin/bash
# Start the service if not already running
if ! systemctl is-active --quiet openwebui; then
    sudo systemctl start openwebui
    sleep 4
fi
# Open browser
xdg-open http://localhost:$PORT
LAUNCHER
        chmod +x "$LAUNCHER"

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

        # Trust the desktop file on GNOME
        gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true

        echo "  ✔ Desktop shortcut created at: $DESKTOP_FILE"
    fi
else
    echo ""
    echo "▶ Step 6: Skipping systemd setup."
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
echo "  • Python            : $PYTHON_VERSION"
echo "  • Venv              : $VENV_DIR"
echo "  • Data directory    : $DATA_DIR"
echo "  • Port              : $PORT"
echo ""
echo "  → Open http://localhost:$PORT in your browser"
echo "  → First time? Create an admin account on first visit."
echo ""
