#!/bin/bash
set -e

# Цвета для логов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

log() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Проверяем, что мы root (su без sudo)
if [ "$EUID" -ne 0 ]; then
  error "Запустите скрипт от root (su -)"
fi

WORK_DIR="/opt/zapret"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Проверка и установка зависимостей libnetfilter_queue
echo -e "${YELLOW}=== Проверка зависимостей для nfqws (libnetfilter_queue) ===${NC}"
if command -v epm >/dev/null 2>&1; then
  log "AltLinux/SimplyLinux обнаружен (epm). Автоустановка..."
  epm install libnetfilter_queue libnetfilter_queue-devel || true
else
  warn "НЕ AltLinux. libnetfilter_queue НЕ установлен автоматически."
  warn "Для nfqws установите вручную:"
  warn "  Debian/Ubuntu: apt install libnetfilter-queue1 libnetfilter-queue-dev"
  warn "  Fedora/RHEL:   dnf install libnetfilter_queue libnetfilter_queue-devel"
  warn "  Arch:          pacman -S libnetfilter_queue"
  warn "  openSUSE:      zypper in libnetfilter_queue1 libnetfilter_queue-devel"
  warn "tpws работает без них"
fi
echo

log "Остановка существующего zapret"
systemctl stop zapret 2>/dev/null || true

log "Копирование $SCRIPT_DIR/zapret → $WORK_DIR"
rm -rf "$WORK_DIR"
cp -a "$SCRIPT_DIR/zapret" "$WORK_DIR"

# Systemd unit /etc/systemd/system/zapret.service
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

log "✅ УСТАНОВЛЕНО:"
log "  Путь: $WORK_DIR"
log "  Config: $WORK_DIR/config"
log "  Domains: $WORK_DIR/ipset/zapret-hosts-user.txt"
log "  Docs: https://github.com/bol-van/zapret"

log "Статус сервиса:"
systemctl status zapret.service --no-pager

exit 0
