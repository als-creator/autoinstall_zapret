#!/bin/bash
set -euo pipefail

TMPDIR="$(mktemp -d)"
REPO="https://github.com/bol-van/zapret.git"
TARGET="/opt/zapret"

command -v sudo >/dev/null 2>&1 || { echo "[ERROR] sudo не установлен"; exit 1; }

echo "[OK] clone"
git clone --depth 1 "$REPO" "$TMPDIR"

echo "[OK] copy"
sudo rm -rf "$TARGET"
sudo cp -a "$TMPDIR" "$TARGET"
# если репо вложено как /tmp/zapret/zapret при клоне чужого репозитория, учтём оба варианта
if [ -d "$TMPDIR/zapret" ] && [ ! -d "$TARGET/init.d" ]; then
  sudo rm -rf "$TARGET"
  sudo cp -a "$TMPDIR/zapret" "$TARGET"
fi

# восстановим права, как делает install_easy.sh
sudo find "$TARGET" -type d -exec chmod 755 {} \; || true
sudo find "$TARGET" -type f -exec chmod 644 {} \; || true
# сохранить исполняемые файлы (в репо они уже исполн.); установим +x для bin и init scripts
sudo find "$TARGET" -path "$TARGET/binaries/*" -type f -exec chmod 755 {} \; || true
sudo find "$TARGET/init.d" -type f -exec chmod 755 {} \; || true

# Попытка установить пакеты (не критично)
if command -v apt-get >/dev/null 2>&1; then
  echo "[OK] apt-get update && install libnetfilter_queue"
  sudo apt-get update >/dev/null 2>&1 || true
  sudo apt-get install -y libnetfilter-queue libnetfilter-queue1 libnetfilter-queue-dev >/dev/null 2>&1 || true
fi

# Создадим минимальный wrapper
sudo mkdir -p "$TARGET/init.d"
sudo tee "$TARGET/init.d/zapret-start" > /dev/null <<'EOF'
#!/usr/bin/env bash
set -e
cd /opt/zapret

# Official repo ships binaries/tpws, nfqws etc. Try typical entry points in order:
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
  # install_easy.sh can re-exec itself from target; try non-interactive run if supported
  exec ./install_easy.sh --run || exec ./install_easy.sh
fi

echo "Нет исполняемого файла в /opt/zapret" >&2
exit 1
EOF
sudo chmod 755 "$TARGET/init.d/zapret-start"

# Install systemd unit(s) from the repo if present
SYSTEMD_DIR="/etc/systemd/system"
if [ -d "$TARGET/init.d/systemd" ]; then
  echo "[OK] installing systemd units from repo"
  sudo cp -f "$TARGET/init.d/systemd/"*.service "$SYSTEMD_DIR/" 2>/dev/null || true
  # also copy timer/service for list updates if present
  sudo cp -f "$TARGET/init.d/systemd/"*.timer "$SYSTEMD_DIR/" 2>/dev/null || true
else
  echo "[OK] writing minimal zapret.service"
  sudo tee /etc/systemd/system/zapret.service > /dev/null <<'UNIT'
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
UNIT
fi

# daemon-reload and enable/start services
sudo systemctl daemon-reload
sudo systemctl enable zapret.service >/dev/null 2>&1 || true
sudo systemctl restart zapret.service || true

# If repo provided zapret-list-update.timer/service, enable+start them
if [ -f "$SYSTEMD_DIR/zapret-list-update.timer" ] || [ -f "$SYSTEMD_DIR/zapret-list-update.service" ]; then
  sudo systemctl daemon-reload
  sudo systemctl enable --now zapret-list-update.timer zapret-list-update.service >/dev/null 2>&1 || true
fi

echo "[OK] status:"
sudo systemctl --no-pager status zapret.service || true
echo "[OK] journal (last 200 lines):"
sudo journalctl -u zapret.service -n 200 --no-pager || true

# cleanup
rm -rf "$TMPDIR"
exit 0
