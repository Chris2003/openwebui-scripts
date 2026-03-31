# 🤖 openwebui-scripts

A collection of scripts I've built and use on my own AI rig — running Open WebUI on a bare Linux machine with a pip + venv setup. No Docker, no containers, just a straight install on Ubuntu.

I'm sharing these in case they're useful to anyone else running a similar setup. Nothing fancy, just stuff that solved real problems I ran into.

---

## Scripts

### `update-openwebui.sh` — Safe Updater

Upgrading Open WebUI via pip can silently wipe your database since `webui.db` lives inside the package directory by default. This script backs up your data, migrates it to a safe persistent location, and upgrades the package — without you having to think about any of it.

```bash
# Update to the latest version
./update-openwebui.sh

# Update to a specific version
./update-openwebui.sh 0.8.12
```

What it does:
- Auto-detects your venv and Python version
- Backs up `webui.db` with a timestamp before anything changes
- Migrates your database out of the venv on first run
- Upgrades the pip package

---

### `setup-openwebui-service.sh` — systemd Service Setup

If you want Open WebUI to start automatically on boot, this script sets it up as a systemd service. It auto-detects your venv, binary path, and current user — no editing required.

```bash
./setup-openwebui-service.sh
```

What it does:
- Auto-detects your venv, binary, and user
- Creates a persistent data directory
- Writes and installs the systemd service file
- Enables it to start on boot and starts it immediately

Useful commands after setup:
```bash
sudo systemctl status openwebui
sudo systemctl restart openwebui
sudo journalctl -u openwebui -f
```

---

## My Setup

For reference, here's what these scripts are built and tested against:

| | |
|---|---|
| **OS** | Ubuntu 24.04 |
| **Install method** | pip + venv |
| **Python** | 3.12 |
| **Open WebUI** | 0.8.x |

---

## Requirements

- Ubuntu / Debian-based Linux
- Open WebUI installed via `pip` inside a virtual environment
- `sudo` access (only needed for the service setup script)

---

## Getting Started

```bash
git clone https://github.com/yourusername/openwebui-scripts.git
cd openwebui-scripts
chmod +x *.sh
```

Then run whichever script you need.

---

## Contributing

If you've adapted these for a different setup — different distro, different install path, conda instead of venv — feel free to open a PR. Happy to expand compatibility.

---

## License

MIT
