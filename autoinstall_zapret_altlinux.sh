#!/bin/bash
set -e

log_ok(){ echo "[OK] $1"; }
log_err(){ echo "[ERROR] $1"; exit 1; }

command -v sudo >/dev/null 2>&1 || { echo "[ERROR] sudo не установлен"; echo "su -"; exit 1; }

log_ok "Скачивание zapret"
TMPDIR=$(mktemp -d)
git clone https://github.com/als-creator/autoinstall_zapret_altlinux.git "$TMPDIR" || log_err "git clone"

sudo rm -rf /opt/zapret
sudo cp -a "$TMPDIR/zapret" /opt/zapret
rm -rf "$TMPDIR"

log_ok "Установка libnetfilter_queue"
sudo apt-get update >/dev/null 2>&1 || true
sudo apt-get install -y libnetfilter_queue || true

sudo systemctl stop zapret.service 2>/dev/null || true

sudo tee /etc/systemd/system/zapret.service > /dev/null <<'EOF'
[Unit]
Description=Zapret DPI bypass
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5
WorkingDirectory=/opt/zapret
ExecStart=/opt/zapret/init.d/zapret-start
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now zapret.service
sudo systemctl restart zapret.service
sudo systemctl --no-pager status zapret.service || true

exit 0
