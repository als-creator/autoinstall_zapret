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

# Функция для проверки доступности пакетного менеджера
check_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v xbps-install &> /dev/null; then
        echo "xbps"
    else
        echo "неизвестный пакетник"
    fi
}

PM=$(check_package_manager)

# Функция для установки пакетов в зависимости от пакетного менеджера
install_dependencies() {
    case "$PM" in
        apt)
            log_ok "Обнаружен пакетный менеджер: apt-get"
            sudo apt-get update >/dev/null 2>&1 || true
            if sudo apt-get install -y libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (apt)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (apt), продолжаем..."
                return 0
            fi
            ;;

        dnf)
            log_ok "Обнаружен пакетный менеджер: dnf"
            sudo dnf check-update >/dev/null 2>&1 || true
            if sudo dnf install -y libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (dnf)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (dnf), продолжаем..."
                return 0
            fi
            ;;

        yum)
            log_ok "Обнаружен пакетный менеджер: yum"
            sudo yum check-update >/dev/null 2>&1 || true
            if sudo yum install -y libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (yum)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (yum), продолжаем..."
                return 0
            fi
            ;;

        pacman)
            log_ok "Обнаружен пакетный менеджер: pacman"
            sudo pacman -Sy >/dev/null 2>&1 || true
            if sudo pacman -S --noconfirm libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (pacman)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (pacman), продолжаем..."
                return 0
            fi
            ;;

        apk)
            log_ok "Обнаружен пакетный менеджер: apk"
            sudo apk update >/dev/null 2>&1 || true
            if sudo apk add libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (apk)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (apk), продолжаем..."
                return 0
            fi
            ;;

        zypper)
            log_ok "Обнаружен пакетный менеджер: zypper"
            sudo zypper refresh >/dev/null 2>&1 || true
            if sudo zypper install -y libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (zypper)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (zypper), продолжаем..."
                return 0
            fi
            ;;

        xbps)
            log_ok "Обнаружен пакетный менеджер: xbps-install"
            sudo xbps-install -Sy >/dev/null 2>&1 || true
            if sudo xbps-install -y libnetfilter_queue git >/dev/null 2>&1; then
                log_ok "Зависимости успешно установлены (xbps)"
                return 0
            else
                log_ok "Установка завершена с предупреждениями (xbps), продолжаем..."
                return 0
            fi
            ;;

        *)
            log_ok "Пакетный менеджер не определен, пропуск установки зависимостей"
            return 0
            ;;
    esac
}

install_dependencies
# Скрипт продолжает выполнение здесь, независимо от результата установки

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
  Скрипт производит автоустановку зависимостей через системный пакетник.
  Если пакетника нет в списке, то можно установить libnetfilter_queue вручную.

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
