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
sudo apt-get install -y libnetfilter_queue >/dev/null 2>&1 || true

# Создаём systemd unit
sudo tee /etc/systemd/system/zapret.service > /dev/null <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Restart=no
TimeoutSec=30sec
IgnoreSIGPIPE=no
KillMode=none
GuessMainPID=no
RemainAfterExit=no
ExecStart=/opt/zapret/init.d/sysv/zapret start
ExecStop=/opt/zapret/init.d/sysv/zapret stop

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

exit 0
