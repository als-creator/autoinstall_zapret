# AutoInstall Zapret для Alt Linux

## Описание

Скрипт автоматизирует установку и настройку zapret  v72.12 от bol-van 
Данный пакет по заявлению автора больше не будет обновляться, поэтому скрипт окончательный.
В целом, хотя и указано что скрипт для altlinux, но разница тут только с зависимостями, которые ставятся через пакетник, основа копируется с помощью git без пакетника, поэтому при установке зависимостей вручную скрипт можно использовать на любом дистре со стандартным расположением директорий.

## Что делает скрипт

1. Проверяет наличие sudo на системе
2. Клонирует репозиторий zapret с GitHub
3. Копирует zapret в /opt/zapret
4. Устанавливает необходимые зависимости если может
5. Создает systemd unit для управления сервисом
6. Включает автозагрузку zapret при старте системы
7. Запускает сервис zapret
8. Выводит информацию о зависимостях, управлении и конфигурации

## Автоустановка

Запустите скрипт по ссылке:

```bash
curl -fsSL https://raw.githubusercontent.com/als-creator/autoinstall_zapret_altlinux/main/autoinstall_zapret_altlinux.sh | sh
```
Скрипт попросит пароль для выполнения команд через sudo.

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

sudo systemctl restart zapret.service

## Удаление zapret

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

## Проверка зависимостей

Проверка наличия sudo:
sudo -v

Проверка наличия git:
git --version

Проверка наличия libnetfilter_queue:
dpkg -l | grep libnetfilter

## Решение проблем

Если сервис не запускается, проверьте логи:
sudo journalctl -u zapret.service -n 50

Если конфиг невалиден, проверьте синтаксис:
cat /opt/zapret/config

[Наборы хостов и правил для перебора под своего провайдера](https://github.com/Snowy-Fluffy/zapret.cfgs)

Если доступа нет, проверьте права доступа:
ls -la /opt/zapret/

## Лицензия

Используется лицензия из оригинального репозитория zapret.
