#!/bin/bash
set -e

log_ok() { echo "[OK] $1"; }
log_error() { echo "[ERROR] $1"; exit 1; }

# Проверка sudo
if ! command -v sudo >/dev/null 2>&1; then
  cat << EOF
[ERROR] sudo не установлен/недоступен

Для активации sudo:
1. su -
2. control sudowheel enabled
3. reboot
4. Запустите скрипт снова
EOF
  exit 1
fi

WORK_DIR="/opt/zapret"
SCRIPT_DIR="\$(dirname "\$(readlink -f "\$0")")"
TEMP_DIR="\$(mktemp -d)"

# Скачивание zapret во временную папку
log_ok "Скачивание zapret"
git clone https://github.com/als-creator/autoinstall_zapret_altlinux.git "\$TEMP_DIR" || log_error "Ошибка git clone"

sudo rm -rf "\$WORK_DIR"
sudo cp -a "\$TEMP_DIR/zapret" "\$WORK_DIR"

log_ok "Установка libnetfilter_queue"
sudo epm install libnetfilter_queue || true

sudo systemctl stop zapret 2>/dev/null || true

# Systemd unit
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

log_ok "Установлен: \$WORK_DIR"
log_ok "Config: \$WORK_DIR/config"
log_ok "Domains: \$WORK_DIR/ipset/zapret-hosts-user.txt"
log_ok "Docs: https://github.com/bol-van/zapret"

sudo systemctl status zapret.service --no-pager

# Очистка
rm -rf "\$TEMP_DIR"

exit 0
