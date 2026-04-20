#!/bin/bash
set -e

log_ok() { echo "[OK] $1"; }
log_error() { echo "[ERROR] $1"; exit 1; }

# Проверка sudo
if ! command -v sudo >/dev/null 2>&1; then
  echo "[ERROR] sudo не установлен"
  echo "su -"
  echo "control sudowheel enabled"
  echo "reboot"
  exit 1
fi

WORK_DIR="/opt/zapret"
TEMP_DIR=$(mktemp -d)

log_ok "Скачивание zapret"
git clone https://github.com/als-creator/autoinstall_zapret_altlinux.git "$TEMP_DIR" || log_error "git clone"

sudo rm -rf "$WORK_DIR"
sudo cp -a "$TEMP_DIR/zapret" "$WORK_DIR"

log_ok "libnetfilter_queue"
sudo epm install libnetfilter_queue || true

sudo systemctl stop zapret 2>/dev/null || true

sudo tee /etc/systemd/system/zapret.service > /dev/null << 'EOF'
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
sudo systemctl enable zapret
sudo systemctl start zapret

echo "[OK] Установлен: $WORK_DIR"
echo "[OK] Config: $WORK_DIR/config"
echo "[OK] Domains: $WORK_DIR/ipset/zapret-hosts-user.txt"
echo "[OK] Docs: https://github.com/bol-van/zapret"

sudo systemctl status zapret.service --no-pager

rm -rf "$TEMP_DIR"

exit 0
