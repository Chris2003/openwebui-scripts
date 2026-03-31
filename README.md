# 🤖 openwebui-scripts

A collection of scripts I've built and use on my own AI rig — running Open WebUI on a bare Linux machine with a pip + venv setup. No Docker, no containers, just a straight install on Ubuntu.

The official Open WebUI repo is almost entirely Docker-focused. These scripts fill the gap for people running it directly on Linux. I'm sharing them in case they're useful to anyone with a similar setup.

---

## Scripts

### `install-openwebui.sh` — Fresh Installer

Sets up Open WebUI from scratch: creates a virtual environment, installs the package, sets up a persistent data directory, and optionally configures a systemd service to run on boot.

```bash
# Install latest version
./install-openwebui.sh

# Install specific version
./install-openwebui.sh 0.8.12
```

---

### `update-openwebui.sh` — Safe Updater

Upgrading Open WebUI via pip can silently overwrite your database since `webui.db` lives inside the package directory by default. This script backs up your data, migrates it to a safe persistent location, and upgrades the package — without you having to think about any of it.

```bash
# Update to the latest version
./update-openwebui.sh

# Update to a specific version
./update-openwebui.sh 0.8.12
```

---

### `setup-openwebui-service.sh` — systemd Service Setup

Sets up Open WebUI as a systemd service so it starts automatically on boot. Auto-detects your venv, binary path, and current user.

```bash
./setup-openwebui-service.sh
```

Useful commands after setup:
```bash
sudo systemctl status openwebui
sudo systemctl restart openwebui
sudo journalctl -u openwebui -f
```

---

### `expose-openwebui.sh` — Network Expose

Makes Open WebUI accessible to anyone on your local network. Ensures Open WebUI binds to `0.0.0.0` instead of `127.0.0.1`, opens the port in UFW if active, restarts the service, and prints every local IP address you can share.

```bash
# Expose on default port 8080
./expose-openwebui.sh

# Expose on a custom port
./expose-openwebui.sh 9090
```

> ⚠️ This exposes Open WebUI to your local network. Do not open the port to the internet without authentication and HTTPS configured.

---

### `backup-openwebui.sh` — Backup

Creates a timestamped `.tar.gz` backup of your Open WebUI data directory. Safe to run while Open WebUI is running. Works standalone or in a cron job.

```bash
# Save backup to current directory
./backup-openwebui.sh

# Save backup to a custom directory
./backup-openwebui.sh /path/to/backups
```

To automate daily backups at 2am, add to cron:
```bash
crontab -e
# Add this line:
0 2 * * * /path/to/backup-openwebui.sh /path/to/backups
```

---

### `restore-openwebui.sh` — Restore

Restores a backup created by `backup-openwebui.sh`. Automatically saves a pre-restore backup of your current data before overwriting anything.

```bash
./restore-openwebui.sh /path/to/openwebui-backup-TIMESTAMP.tar.gz
```

---

### `uninstall-openwebui.sh` — Uninstaller

Cleanly removes Open WebUI from your system. Stops and removes the systemd service if present. Gives you the choice to keep or wipe your data. Creates a final backup before wiping.

```bash
./uninstall-openwebui.sh
```

---

### `update-ollama.sh` — Ollama Updater

Updates the Ollama binary to the latest version on bare Linux installs. Does not touch your models or configuration.

```bash
./update-ollama.sh
```

---

## Full Lifecycle

```
install-openwebui.sh        ← start here
        ↓
setup-openwebui-service.sh  ← optional: run on boot
        ↓
expose-openwebui.sh         ← optional: open to local network
        ↓
backup-openwebui.sh         ← run regularly / cron
        ↓
update-openwebui.sh         ← when new version drops
        ↓
restore-openwebui.sh        ← if something goes wrong
        ↓
uninstall-openwebui.sh      ← clean removal
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
| **Ollama** | bare Linux install |

---

## Requirements

- Ubuntu / Debian-based Linux
- Python 3.11 or higher
- `sudo` access (for service-related scripts)

---

## Getting Started

```bash
git clone https://github.com/Chris2003/openwebui-scripts.git
cd openwebui-scripts
chmod +x *.sh
```

Then start with `./install-openwebui.sh` if you're setting up fresh, or jump to whichever script fits your situation.

---

## Contributing

If you've adapted these for a different setup — different distro, Python version, conda instead of venv — feel free to open a PR. Happy to expand compatibility.

---

## License

MIT
