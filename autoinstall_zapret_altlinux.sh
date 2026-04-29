#!/bin/bash
set -e

log_ok(){ echo "[OK] $1"; }
log_err(){ echo "[ERROR] $1"; exit 1; }

command -v sudo >/dev/null 2>&1 || log_err "sudo не установлен"

log_ok "Скачивание zapret"
TMPDIR=$(mktemp -d)
git clone https://github.com/als-creator/autoinstall_zapret_altlinux.git "$TMPDIR" || log_err "git clone failed"

sudo rm -rf /opt/zapret
sudo cp -a "$TMPDIR/zapret" /opt/zapret
rm -rf "$TMPDIR"
log_ok "/opt/zapret установлен"

log_ok "Установка зависимостей"
sudo apt-get update >/dev/null 2>&1 || true
sudo apt-get install -y libnetfilter_queue git sudo >/dev/null 2>&1 || {
    log_ok "Зависимости установлены с ошибками или пропущены, продолжаем..."
}

sudo tee /etc/systemd/system/zapret.service > /dev/null <<'EOF'
[Unit]
# Запускать после подключения к сети
After=network-online.target
# Мягкая зависимость — попытаться запустить сеть, но не требовать её
Wants=network-online.target

[Service]
# Тип сервиса — process создаёт дочерние процессы и сервис остаётся активным
Type=forking
# Перезапускать сервис при ошибке (ненулевой выход)
Restart=on-failure
# Ждать 10 секунд перед перезапуском
RestartSec=10s
# Максимум 3 перезапуска за 60 секунд (защита от бесконечных перезапусков)
StartLimitInterval=60s
# Количество разрешённых перезапусков в интервале
StartLimitBurst=3
# Таймаут на запуск и остановку сервиса
TimeoutSec=30sec
# Убивать только основной процесс, не дочерние
KillMode=process
# Не пытаться автоматически определять PID основного процесса
GuessMainPID=no
# Команда для запуска сервиса
ExecStart=/opt/zapret/init.d/sysv/zapret start
# Команда для остановки сервиса
ExecStop=/opt/zapret/init.d/sysv/zapret stop

[Install]
# Включить сервис при загрузке системы в режиме multi-user (обычный режим)
WantedBy=multi-user.target

EOF
log_ok "Unit /etc/systemd/system/zapret.service записан"

sudo systemctl daemon-reload >/dev/null 2>&1 || true
sudo systemctl enable zapret.service >/dev/null 2>&1 || true
sudo systemctl restart zapret.service >/dev/null 2>&1 || true

log_ok "Статус сервиса:"
sudo systemctl --no-pager status zapret.service || true

cat << 'EOF'

════════════════════════════════════════════════════════════════════
                    ИНФОРМАЦИЯ О ЗАВИСИМОСТЯХ
════════════════════════════════════════════════════════════════════

• sudo - Необходим для выполнения команд с повышенными привилегиями
  Требуется при: установке и управлении сервисом zapret
  Проверка: sudo -v

• git - Необходим для клонирования репозитория
  Требуется при: загрузке исходного кода zapret
  Проверка: git --version

• libnetfilter_queue - Требуется для фильтрации сетевых пакетов
  Требуется при: использовании режимов NFQUEUE, TPWS, TPWS+
  Проверка режима: cat /opt/zapret/config | grep -i mode
  Если режим содержит: NFQUEUE, TPWS или TPWS+ - зависимость необходима

════════════════════════════════════════════════════════════════════
                      УПРАВЛЕНИЕ СЕРВИСОМ
════════════════════════════════════════════════════════════════════

Запуск сервиса:
  sudo systemctl start zapret.service

Остановка сервиса:
  sudo systemctl stop zapret.service

Перезагрузка сервиса:
  sudo systemctl restart zapret.service

Проверка статуса:
  sudo systemctl status zapret.service

Просмотр логов:
  sudo journalctl -u zapret.service -f

Отключение автозагрузки:
  sudo systemctl disable zapret.service

Включение автозагрузки:
  sudo systemctl enable zapret.service

════════════════════════════════════════════════════════════════════
                    КОНФИГУРАЦИЯ ZAPRET
════════════════════════════════════════════════════════════════════

Основной конфиг:
  /opt/zapret/config
  Редактирование: sudo nano /opt/zapret/config

  Основные параметры:
  • MODE - режим работы (NFQUEUE, TPWS, TPWS+, FAKE, etc)
  • TPWS_PORT - порт для TPWS
  • IPSET - набор IP адресов для обработки

Список доменов для блокировки:
  /opt/zapret/ipset/zapret-hosts-user.txt
  Редактирование: sudo nano /opt/zapret/ipset/zapret-hosts-user.txt

  Формат: один домен на строку
  Пример:
    example.com
    blocked.site
    forbidden.net

sudo systemctl restart zapret.service после редактирования.

════════════════════════════════════════════════════════════════════
                    УДАЛЕНИЕ ZAPRET
════════════════════════════════════════════════════════════════════
Если zapret больше не требуется, выполните следующие команды:

Отключение автозагрузки:
sudo systemctl disable --now zapret.service

Удаление systemd unit:
sudo rm /etc/systemd/system/zapret.service

Перезагрузка systemd:
sudo systemctl daemon-reload

Удаление файлов zapret:
sudo rm -rf /opt/zapret

Удаление зависимостей (опционально):
sudo apt-get remove libnetfilter_queue


════════════════════════════════════════════════════════════════════

EOF

exit 0
