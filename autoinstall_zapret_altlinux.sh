#!/bin/bash
set -e

# autoinstall_zapret_altlinux.sh
# Установка zapret для AltLinux

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  cat << 'EOF'

🔥 autoinstall_zapret_altlinux

Запуск:
  curl -fsSL https://raw.githubusercontent.com/als-creator/autoinstall_zapret_altlinux/main/autoinstall_zapret_altlinux.sh -o autoinstall.sh
  su -c 'bash autoinstall.sh'

EOF
  exit 1
fi

WORK_DIR="/opt/zapret"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

log "Установка libnetfilter_queue (для nfqws)"
epm install libnetfilter_queue || warn "Пакет не найден (tpws работает без него)"

log "Остановка существующего zapret"
systemctl stop zapret 2>/dev/null || true

log "Копирование $SCRIPT_DIR/zapret → $WORK_DIR"
rm -rf "$WORK_DIR"
cp -a "$SCRIPT_DIR/zapret" "$WORK_DIR"

# Systemd unit
cat > /etc/systemd/system/zapret.service << 'EOF'
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

log "Настройка systemd сервиса"
systemctl daemon-reload
systemctl enable zapret
systemctl start zapret

cat << EOF

✅ ${GREEN}zapret УСТАНОВЛЕН${NC}

📁 Путь: $WORK_DIR
⚙️  Config: $WORK_DIR/config
📋 Domains: $WORK_DIR/ipset/zapret-hosts-user.txt
📚 Документация: https://github.com/bol-van/zapret

log "Статус:"
EOF

systemctl status zapret.service --no-pager

exit 0
