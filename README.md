# AutoInstall Zapret

## Описание

Скрипт автоматизирует установку и настройку zapret v72.12 от bol-van  
Данный пакет по заявлению автора больше не будет обновляться, поэтому скрипт окончательный.  
Тестировалось на altlinux, но отличие тут только в libnetfilter_queue, который ставятся через пакетник и может называться по разному в разных дистрах, основа копируется с помощью git без пакетника, поэтому при установке зависимостей вручную скрипт можно использовать на любом дистре со стандартным расположением директорий.

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
curl -fsSL https://raw.githubusercontent.com/als-creator/autoinstall_zapret/main/autoinstall_zapret.sh | sh
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
 Редактирование:

```bash
  sudo nano /opt/zapret/config
```

Основные параметры:  
 • MODE - режим работы (NFQUEUE, TPWS, TPWS+, FAKE, etc)  
 • TPWS_PORT - порт для TPWS  
 • IPSET - набор IP адресов для обработки

Список доменов для блокировки:  
/opt/zapret/ipset/zapret-hosts-user.txt

Редактирование:

```bash
sudo nano /opt/zapret/ipset/zapret-hosts-user.txt
```

Формат: один домен на строку  
Пример:  
example.com  
blocked.site  
forbidden.net

```bash
sudo systemctl restart zapret.service
```

## Удаление zapret

Если zapret больше не требуется, выполните следующие команды:

```bash
su -c '
  if systemctl list-unit-files | grep -q "zapret.service"; then
    systemctl disable --now zapret.service
    rm /etc/systemd/system/zapret.service
    systemctl daemon-reload
  fi
  rm -rf /opt/zapret
'
```

То же самое в несколько команд:

Отключение автозагрузки:

```bash
sudo systemctl disable --now zapret.service
```

Удаление systemd unit:

```bash
sudo rm /etc/systemd/system/zapret.service
```

Перезагрузка systemd:

```bash
sudo systemctl daemon-reload
```

Удаление файлов zapret:

```bash
sudo rm -rf /opt/zapret
```

## Проверка зависимостей

Проверка наличия sudo:

```bash
sudo -v
```

Проверка наличия git:

```bash
git --version
```

Проверка наличия libnetfilter_queue:

```bash
dpkg -l | grep libnetfilter
```

## Решение проблем

Если сервис не запускается, проверьте логи:

```bash
sudo journalctl -u zapret.service -n 50
```

Если конфиг невалиден, проверьте синтаксис:

```bash
cat /opt/zapret/config
```

[Наборы хостов и правил для перебора под своего провайдера](https://github.com/Snowy-Fluffy/zapret.cfgs)

Если доступа нет, проверьте права доступа:

```bash
ls -la /opt/zapret/
```

Если сервис работает, но ничего не воспроизводится, то можно прогнать вручную тест для настройки:

```bash
sudo /opt/zapret/install_easy.sh
```

Примерные ответы теста:

```bash
select firewall type : nftables
enable ipv6 support (default : N) (Y/N) ? n
select flow offloading : none
select filtering : hostlist
enable tpws socks mode on port 987 ? (default : N) (Y/N) ? n
enable tpws transparent mode ? (default : N) (Y/N) ? n
enable nfqws ? (default : Y) (Y/N) ? y
LAN interface :
1 : enp37s0
2 : lo
3 : tun0
4 : wlan0
your choice (default : enp37s0) : 1
selected : enp37s0
WAN interface :
1 : enp37s0
2 : lo
3 : tun0
4 : wlan0
your choice (default : ) :
selected :

do you want to auto download ip/host list (default : Y) (Y/N) ? y
1 : get_refilter_domains.sh
2 : get_antizapret_domains.sh
3 : get_reestr_resolvable_domains.sh
your choice (default : get_refilter_domains.sh) : y
selected : get_refilter_domains.sh
```

Если не помогло, то попробовать другое [правило](https://github.com/Snowy-Fluffy/zapret.cfgs/tree/main/configurations) для /opt/zapret/config

## Лицензия

Используется лицензия из оригинального репозитория zapret.
