# AutoInstall Zapret

## Описание

Скрипт автоматизирует установку и настройку zapret v72.x  
Данная ветка (v1) по заявлению автора больше не обновляется (EOL), поэтому
скрипт **не клонирует** репозиторий bol-van, а берёт zapret из репозитория
[als-creator/autoinstall_zapret_altlinux](https://github.com/als-creator/autoinstall_zapret_altlinux)
(локальная папка `zapret/` в проекте или fallback-клонирование).

Бинарники nfqws/tpws/ip2net/mdig — **предсобранные и статически слинкованные**,
поэтому работают на любом дистрибутиве Linux без компиляции и без
libnetfilter_queue. Скрипт сам выбирает FWTYPE (iptables/nftables),
ставит минимальные зависимости (iptables/nftables, ipset, curl) и
проверяет, что правило реально применилось.

## Что делает скрипт

1. Проверяет наличие sudo на системе
2. Устанавливает зависимости: curl, gzip, ipset, iptables/nftables
3. Берёт zapret из локальной папки `zapret/` или клонирует ваш репозиторий
4. Копирует zapret в /opt/zapret
5. Автоматически определяет архитектуру и подключает подходящий статический бинарник
6. Определяет и прописывает FWTYPE (iptables или nftables)
7. Пишет конфиг с NFQWS-правилом и списки хостов/исключений
8. Создает systemd unit и включает автозагрузку
9. Запускает сервис и проверяет, что правило применилось
10. Выводит информацию о конфигурации

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

• git - Необходим только как fallback, когда папка zapret/ отсутствует рядом со скриптом  
 Требуется при: клонировании репозитория  
 Проверка: git --version

• iptables или nftables - Необходим для применения правил в ядре (цепочка ZAPRET в mangle / таблица zapret)  
 Требуется при: перехвате трафика демоном nfqws через NFQUEUE

• ipset - Необходим для эффективных наборов IP/доменов при режиме autohostlist  
 Требуется при: работе с большими списками доменов

• curl - Необходим для скачивания списков доменов (getlist)

• libnetfilter_queue - НЕ нужен при использовании предсобранных статических бинарников.
 Нужен ТОЛЬКО при сборке nfqws из исходников. Если собираете вручную, имена пакета по дистрибутивам:

| Дистрибутив / пакетник | Пакет для сборки |
|---|---|
| Debian / Ubuntu (apt) | libnetfilter-queue-dev (рантайм: libnetfilter-queue1) |
| Fedora / RHEL / CentOS (dnf/yum) | libnetfilter_queue-devel |
| Arch / EndeavourOS (pacman) | libnetfilter_queue |
| Alpine (apk) | libnetfilter_queue-dev |
| openSUSE (zypper) | libnetfilter_queue-devel |
| Void Linux (xbps) | libnetfilter_queue-devel |
| Gentoo (emerge) | net-libs/libnetfilter_queue |

Зачем вообще нужен libnetfilter_queue: демон nfqws общается с ядром через
netfilter queue (NFQUEUE). Ядро кладёт подходящие пакеты в очередь, а nfqws
с помощью этой библиотеки (nfq_open/nfq_bind_pf) читает их, модифицирует для
обхода DPI и возвращает обратно. Без неё nfqws не может открыть очередь —
при сборке из исходников нужны dev-заголовки, при использовании статических
бинарников (как в этом скрипте) она уже «вшита» и никакие пакеты не нужны.

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

Проверка наличия iptables/nftables:

```bash
command -v iptables && command -v ipset
```

Если скрипт определил nftables и необходимости в iptables нет, нужен только ipset и nft:

```bash
command -v nft && command -v ipset
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
