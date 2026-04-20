#!/bin/bash
set -e

log_ok(){ echo "[OK] $1"; }
log_err(){ echo "[ERROR] $1"; exit 1; }

command -v sudo >/dev/null 2>&1 || { echo "[ERROR] sudo не установлен"; echo "su -"; exit 1; }

log_ok "Скачивание zapret"
TMPDIR=$(mktemp -d)
git clone https://github.com/als-creator/autoinstall_zapret_altlinux.git "$TMPDIR" || log_err "git clone failed"

sudo rm -rf /opt/zapret
sudo cp -a "$TMPDIR/zapret" /opt/zapret
rm -rf "$TMPDIR"
log_ok "/opt/zapret установлен"

log_ok "Установка libnetfilter_queue"
sudo apt-get update >/dev/null 2>&1 || true
sudo apt-get install -y libnetfilter-queue libnetfilter-queue-dev libnetfilter-queue1 >/dev/null 2>&1 || true

# Создаём wrapper запуска, если нет
sudo mkdir -p /opt/zapret/init.d
sudo tee /opt/zapret/init.d/zapret-start > /dev/null <<'EOF'
#!/usr/bin/env bash
set -e
cd /opt/zapret

# Попытки найти рабочий исполняемый файл в репо
if [ -x ./binaries/zapret ]; then
  exec ./binaries/zapret
fi

if [ -x ./zapret ]; then
  exec ./zapret
fi

if [ -x ./start.sh ]; then
  exec ./start.sh
fi

if [ -x ./install_easy.sh ]; then
  # Some repos use install scripts; try non-interactive run if supported
  exec ./install_easy.sh --run || exec ./install_easy.sh
fi

echo "нет исполняемого файла в /opt/zapret" >&2
exit 1
EOF
sudo chmod +x /opt/zapret/init.d/zapret-start
log_ok "Wrapper /opt/zapret/init.d/zapret-start создан"

# Создаём systemd unit
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
log_ok "Unit /etc/systemd/system/zapret.service записан"

# Перезагрузить daemon, включить и запустить сервис
sudo systemctl daemon-reload
sudo systemctl enable zapret.service >/dev/null 2>&1 || true
sudo systemctl restart zapret.service || true

log_ok "Статус сервиса:"
sudo systemctl --no-pager status zapret.service || true

log_ok "Последние журналы (200 строк):"
sudo journalctl -u zapret.service -n 200 --no-pager || true

exit 0
