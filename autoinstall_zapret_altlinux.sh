#!/bin/bash
set -e

# Цвета для логов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

WORK_DIR="/opt/zapret"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Проверка прав root (один раз)
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Нужны права root. Получение через su...${NC}"
  exec su -c "$(cat "$0" | grep -v '^#')" root
fi

log "Установка libnetfilter_queue для nfqws"
epm install libnetfilter_queue || true

log "Остановка zapret"
systemctl stop zapret 2>/dev/null || true

log "Копирование $SCRIPT_DIR/zapret → $WORK_DIR"
rm -rf "$WORK_DIR"
cp -a "$SCRIPT_DIR/zapret" "$WORK_DIR"

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

log "Настройка systemd"
systemctl daemon-reload
systemctl enable zapret
systemctl start zapret

log "✅ УСТАНОВЛЕНО:"
log "  Путь: $WORK_DIR"
log "  Config: $WORK_DIR/config"
log "  Domains: $WORK_DIR/ipset/zapret-hosts-user.txt"
log "  Docs: https://github.com/bol-van/zapret"

log "Статус сервиса:"
systemctl status zapret.service --no-pager

exit 0
