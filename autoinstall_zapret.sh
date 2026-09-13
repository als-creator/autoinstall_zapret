#!/bin/bash
#
# Universal installer for zapret v1 (EOL, bol-van/zapret)
# Source: als-creator/autoinstall_zapret_altlinux (prebuilt static binaries)
# Install to /opt/zapret, auto-detect firewall type, write NFQWS rule + hostlists,
# create systemd unit, verify.
#
# Static binaries require NO libnetfilter_queue — only iptables/nftables + ipset.
# libnetfilter_queue is needed ONLY when building from source (see --build flag or README).
#
set -uo pipefail

log_ok(){ echo "[OK] $*"; }
log_warn(){ echo "[WARN] $*"; }
log_err(){ echo "[ERROR] $*"; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] && log_err "Не запускайте скрипт от root."
command -v sudo >/dev/null 2>&1 || log_err "sudo не установлен"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_URL="https://github.com/als-creator/autoinstall_zapret_altlinux.git"

# ---------------------------------------------------------------------------
# Package manager detection
# ---------------------------------------------------------------------------
check_package_manager(){
    if   command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null;     then echo "dnf"
    elif command -v zypper &>/dev/null;  then echo "zypper"
    elif command -v yum &>/dev/null;     then echo "yum"
    elif command -v pacman &>/dev/null;  then echo "pacman"
    elif command -v apk &>/dev/null;     then echo "apk"
    elif command -v xbps-install &>/dev/null; then echo "xbps"
    else echo "unknown"; fi
}
PM=$(check_package_manager)

# ---------------------------------------------------------------------------
# Runtime dependencies.
# iptables|nftables — kernel firewall rules (NFQUEUE, mangle chain)
# ipset             — efficient IP/domain sets for autohostlist
# curl              — list downloads (getlist, blockcheck)
# gzip              — compressed hostlists (GZIP_LISTS=1)
# NOTE: libnetfilter_queue is NOT needed for prebuilt static binaries.
#       It is only needed when building nfqws from source.
# ---------------------------------------------------------------------------
get_pkg_lists(){
    case "$PM" in
        apt)  PKGS="curl gzip ipset iptables" ;;
        dnf|yum) PKGS="curl gzip ipset iptables" ;;
        pacman) PKGS="curl gzip ipset iptables" ;;
        apk)  PKGS="curl gzip ipset iptables" ;;
        zypper) PKGS="curl gzip ipset iptables" ;;
        xbps) PKGS="curl gzip ipset iptables" ;;
        *)    PKGS="" ;;
    esac
}

pm_install(){
    local pkgs="$*"
    [ -n "${pkgs// }" ] || return 0
    log_ok "Установка пакетов: $pkgs"
    case "$PM" in
        apt)   sudo apt-get update -qq >/dev/null 2>&1
               sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $pkgs ;;
        dnf)   sudo dnf -y --setopt=install_weak_deps=False install $pkgs ;;
        yum)   sudo yum -y install $pkgs ;;
        pacman) sudo pacman -S --noconfirm --needed $pkgs ;;
        apk)   sudo apk add --no-cache $pkgs ;;
        zypper) sudo zypper refresh >/dev/null 2>&1 || true
                sudo zypper --non-interactive install $pkgs ;;
        xbps)  sudo xbps-install -y $pkgs ;;
        *)     return 1 ;;
    esac
}

get_pkg_lists
pm_install "$PKGS" || log_warn "Не удалось установить зависимости: curl, ipset, iptables/nftables"

# ---------------------------------------------------------------------------
# Firewall backend auto-detection
# ---------------------------------------------------------------------------
detect_fwtype(){
    if command -v iptables >/dev/null 2>&1 && [ -x "$(command -v iptables)" ]; then
        echo "iptables"
    elif command -v nft >/dev/null 2>&1; then
        echo "nftables"
    else
        echo "iptables"
    fi
}
FWTYPE_UNIVERSAL=$(detect_fwtype)
log_ok "Тип файрвола: $FWTYPE_UNIVERSAL"

if [ "$FWTYPE_UNIVERSAL" = nftables ]; then
    pm_install nftables >/dev/null 2>&1 || true
else
    pm_install ip6tables >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Source: local zapret/ dir → fallback: clone from user's GitHub repo
# ---------------------------------------------------------------------------
ZAPRET_SRC=""
if [ -d "$SCRIPT_DIR/zapret" ]; then
    log_ok "Источник: локальная папка $SCRIPT_DIR/zapret (ваш репозиторий)"
    ZAPRET_SRC="$SCRIPT_DIR/zapret"
else
    command -v git >/dev/null 2>&1 || log_err "git не установлен, а папка zapret/ рядом со скриптом не найдена"
    TMPDIR_UNI="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_UNI"' EXIT
    log_ok "Клонирование репозитория $REPO_URL"
    git clone --depth=1 "$REPO_URL" "$TMPDIR_UNI/clone" || log_err "git clone не удался"
    if [ -d "$TMPDIR_UNI/clone/zapret" ]; then
        ZAPRET_SRC="$TMPDIR_UNI/clone/zapret"
    else
        log_err "Папка zapret/ не найдена в репозитории"
    fi
fi

# ---------------------------------------------------------------------------
# Install to /opt/zapret
# ---------------------------------------------------------------------------
sudo rm -rf /opt/zapret
sudo cp -a "$ZAPRET_SRC" /opt/zapret
log_ok "/opt/zapret скопирован"

# ---------------------------------------------------------------------------
# Architecture detection & binary installation
# Prebuilt static binaries work on any distro without libnetfilter_queue.
# ---------------------------------------------------------------------------
log_ok "Определение архитектуры..."
ARCH_RESULT=""
if cd /opt/zapret && ARCH_RESULT=$(bash install_bin.sh getarch 2>/dev/null); then
    log_ok "Архитектура: $ARCH_RESULT"
    cd "$SCRIPT_DIR"
else
    cd "$SCRIPT_DIR"
    # Manual fallback mapping
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
        x86_64)          ARCH_RESULT="linux-x86_64" ;;
        i?86)            ARCH_RESULT="linux-x86" ;;
        aarch64)         ARCH_RESULT="linux-arm64" ;;
        armv[67]l|armv7) ARCH_RESULT="linux-arm" ;;
        *)               log_err "Архитектура $ARCH_RAW не поддерживается предсобранными бинарниками" ;;
    esac
    log_ok "Архитектура (по uname): $ARCH_RESULT (ручное определение)"
fi

# Install binaries via install_bin.sh
if sudo bash /opt/zapret/install_bin.sh 2>&1 | grep -qE "OK|linking|copying"; then
    log_ok "Бинарники установлены (install_bin.sh)"
else
    log_warn "install_bin.sh не сработал автоматически, пробуем линковку вручную..."
    case "$ARCH_RESULT" in
        linux-x86_64|linux-x86|linux-arm64|linux-arm) ;;
        *) log_err "Неизвестная архитектура: $ARCH_RESULT" ;;
    esac
    sudo bash -c "cd /opt/zapret && ln -sf ../binaries/$ARCH_RESULT/nfqws nfq/nfqws"
    sudo bash -c "cd /opt/zapret && ln -sf ../binaries/$ARCH_RESULT/tpws tpws/tpws"
    sudo bash -c "cd /opt/zapret && ln -sf ../binaries/$ARCH_RESULT/ip2net ip2net/ip2net"
    sudo bash -c "cd /opt/zapret && ln -sf ../binaries/$ARCH_RESULT/mdig mdig/mdig"
    log_ok "Бинарники слинкованы вручную"
fi

# Verify binaries
[ -x /opt/zapret/nfq/nfqws ] || log_err "nfqws не найден/не запускается"
log_ok "nfqws: $(file /opt/zapret/nfq/nfqws | sed 's/.*: //')"

sudo mkdir -p /opt/zapret/ipset /opt/zapret/files

# ---------------------------------------------------------------------------
# Service user
# ---------------------------------------------------------------------------
if ! id -u zapret >/dev/null 2>&1; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin zapret 2>/dev/null \
        || sudo useradd --system --no-create-home --shell /bin/false zapret 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Config with the same rule as the working Arch script
# ---------------------------------------------------------------------------
sudo tee /opt/zapret/config >/dev/null <<EOF
# this file is included from init scripts
# change values here

#TMPDIR=/opt/zapret/tmp

# redefine user for zapret daemons
WS_USER=zapret

# override firewall type : iptables,nftables
FWTYPE=$FWTYPE_UNIVERSAL

SET_MAXELEM=522288
IPSET_OPT="hashsize 262144 maxelem \$SET_MAXELEM"

IP2NET_OPT4="--prefix-length=22-30 --v4-threshold=3/4"
IP2NET_OPT6="--prefix-length=56-64 --v6-threshold=5"

AUTOHOSTLIST_RETRANS_THRESHOLD=3
AUTOHOSTLIST_FAIL_THRESHOLD=3
AUTOHOSTLIST_FAIL_TIME=60
AUTOHOSTLIST_DEBUGLOG=0

MDIG_THREADS=30

GZIP_LISTS=1

DESYNC_MARK=0x40000000
DESYNC_MARK_POSTNAT=0x20000000

TPWS_SOCKS_ENABLE=0
TPPORT_SOCKS=987
TPWS_SOCKS_OPT="
--filter-tcp=80 --methodeol <HOSTLIST> --new
--filter-tcp=443 --split-tls=sni --disorder <HOSTLIST>
"

TPWS_ENABLE=0
TPWS_PORTS=80,443
TPWS_OPT="
--filter-tcp=80 --methodeol <HOSTLIST> --new
--filter-tcp=443 --split-tls=sni --disorder <HOSTLIST>
"

NFQWS_ENABLE=1
NFQWS_PORTS_TCP=80,443
NFQWS_PORTS_UDP=443,50000-65535
NFQWS_TCP_PKT_OUT=\$((6+\$AUTOHOSTLIST_RETRANS_THRESHOLD))
NFQWS_TCP_PKT_IN=3
NFQWS_UDP_PKT_OUT=\$((6+\$AUTOHOSTLIST_RETRANS_THRESHOLD))
NFQWS_UDP_PKT_IN=0
NFQWS_OPT="
--filter-udp=443 --hostlist="/opt/zapret/ipset/zapret-hosts-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="/opt/zapret/files/fake/quic_initial_www_google_com.bin" --hostlist-exclude="/opt/zapret/ipset/zapret-hosts-user-exclude.txt" --new ^
--filter-udp=50000-65535  --dpi-desync=fake --dpi-desync-any-protocol --dpi-desync-cutoff=d3 --dpi-desync-repeats=6 --hostlist-exclude="/opt/zapret/ipset/zapret-hosts-user-exclude.txt" --new ^
--filter-tcp=443 --hostlist="/opt/zapret/ipset/zapret-hosts-user.txt" --dpi-desync=fake,split --dpi-desync-autottl=2 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls="/opt/zapret/files/fake/tls_clienthello_www_google_com.bin" --hostlist-exclude="/opt/zapret/ipset/zapret-hosts-user-exclude.txt""
MODE_FILTER=autohostlist

FLOWOFFLOAD=donttouch

INIT_APPLY_FW=1

DISABLE_IPV6=1

#GETLIST=
EOF
log_ok "Конфиг /opt/zapret/config записан (FWTYPE=$FWTYPE_UNIVERSAL)"

# ---------------------------------------------------------------------------
# Hostlists
# ---------------------------------------------------------------------------
sudo tee /opt/zapret/ipset/zapret-hosts-user.txt >/dev/null <<'EOF'
youtube.com
googlevideo.com
ggpht.com
ytimg.com
yt.be
youtu.be
googleadservices.com
gvt1.com
youtube-nocookie.com
youtube-ui.l.google.com
youtubeembeddedplayer.googleapis.com
youtube.googleapis.com
youtubei.googleapis.com
jnn-pa.googleapis.com
yt-video-upload.l.google.com
wide-youtube.l.google.com
play.google.com
accounts.google.com
youtubekids.com
fonts.googleapis.com
googleads.g.doubleclick.net
news.google.com
instagram.com
www.instagram.com
cdninstagram.com
www.cdninstagram.com
facebook.com
www.facebook.com
fbcdn.net
www.fbcdn.net
fburl.com
fbsbx.com
twitter.com
twimg.com
t.co
x.com
rutor.info
rutor.is
nnmclub.to
rutracker.org
rutracker.cc
discord.com
discord.co
discord.app
discord.gg
discordapp.com
discordapp.net
discordcdn.com
discordstatus.com
discord.media
dis.gd
discord-attachments-uploads-prd.storage.googleapis.com
cloudflare-ech.com
cloudflare.com
1.1.1.1
amazon.com
amazonaws.com
ntc.party
torproject.org
meduza.io
te-st.org
EOF

sudo tee /opt/zapret/ipset/zapret-hosts-user-exclude.txt >/dev/null <<'EOF'
# Файл исключений для zapret
# Домены и IP-адреса, которые НЕ должны обрабатываться zapret
# Формат: один домен/IP на строку
EOF

sudo chown -R zapret:zapret /opt/zapret/ipset 2>/dev/null || true

# ---------------------------------------------------------------------------
# systemd unit
# ---------------------------------------------------------------------------
sudo tee /etc/systemd/system/zapret.service >/dev/null <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Restart=on-failure
RestartSec=10s
TimeoutSec=30sec
KillMode=process
GuessMainPID=no
ExecStart=/opt/zapret/init.d/sysv/zapret start
ExecStop=/opt/zapret/init.d/sysv/zapret stop

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload >/dev/null 2>&1
sudo systemctl enable zapret.service >/dev/null 2>&1 || true
sudo systemctl restart zapret.service >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
sleep 2
log_ok "Статус сервиса:"
sudo systemctl --no-pager --type=service status zapret.service --lines=5 2>/dev/null | head -8 || true

echo
if pgrep -x nfqws >/dev/null 2>&1; then
    log_ok "Демон nfqws запущен"
else
    log_warn "nfqws не запущен — смотрите журнал: sudo journalctl -u zapret.service -n 50"
fi

verify_fw(){
    case "$FWTYPE_UNIVERSAL" in
        iptables)
            if sudo iptables -t mangle -nL ZAPRET >/dev/null 2>&1; then
                log_ok "Правила применены: цепочка ZAPRET в mangle присутствует"
            else
                log_warn "Цепочка ZAPRET не найдена. Проверьте: sudo iptables -t mangle -nL"
            fi
            ;;
        nftables)
            if sudo nft list chain inet zapret post >/dev/null 2>&1 || \
               sudo nft list tables 2>/dev/null | grep -q zapret; then
                log_ok "Правила применены: таблица zapret в nftables присутствует"
            else
                log_warn "Таблица zapret не найдена. Проверьте: sudo nft list tables"
            fi
            ;;
    esac
}
verify_fw

cat <<'EOF'

════════════════════════════════════════════════════════════════════
                    КОНФИГУРАЦИЯ ZAPRET (v1)
════════════════════════════════════════════════════════════════════

Источник: als-creator/autoinstall_zapret_altlinux
Бинарники: предсобранные статические (работают на любом дистрибутиве)

Основной конфиг:
  /opt/zapret/config
  Редактирование: sudo nano /opt/zapret/config

Список доменов для обработки:
  /opt/zapret/ipset/zapret-hosts-user.txt

Список исключений (что НЕ обрабатывать):
  /opt/zapret/ipset/zapret-hosts-user-exclude.txt

После редактирования:
  sudo systemctl restart zapret.service

Запуск / остановка / статус / логи:
  sudo systemctl start|stop|restart zapret.service
  sudo systemctl status zapret.service
  sudo journalctl -u zapret.service -f

Зависимости (только для работы):
  iptables/nftables + ipset + curl
  libnetfilter_queue НЕ нужен (бинарники статические)

Удаление:
  sudo systemctl disable --now zapret.service
  sudo rm /etc/systemd/system/zapret.service
  sudo systemctl daemon-reload
  sudo rm -rf /opt/zapret

Готовые наборы правил под провайдера:
  https://github.com/Snowy-Fluffy/zapret.cfgs
EOF

exit 0
