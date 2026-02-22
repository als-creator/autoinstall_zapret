#!/bin/bash
set -e

# Цвета
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Проверка sudo
[ "$EUID" -eq 0 ] && error "Не запускайте от root"
command -v sudo >/dev/null 2>&1 || error "Требуется sudo"

log "Проверка Alt Linux: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Alt Linux')"

# Зависимости Alt Linux (apt или dnf)
if command -v apt-get >/dev/null 2>&1; then
  PKGMGR="apt-get -y install"
  DEPS="gcc-c++ make libmnl-devel zlib-devel libcap-devel libnetfilter_queue-devel libnfnetlink-devel nftables iptables ipset bind curl git unzip systemd-devel"
elif command -v dnf >/dev/null 2>&1; then
  PKGMGR="dnf install -y"
  DEPS="gcc-c++ make libmnl-devel zlib-devel libcap-devel libnetfilter_queue-devel libnfnetlink-devel nftables iptables ipset bind curl git unzip systemd-devel"
else
  error "Не найден apt-get/dnf"
fi

# Проверка ключевых пакетов
for pkg in gcc-c++ make git curl nftables; do
  command -v "$pkg" >/dev/null 2>&1 || {
    warn "Отсутствует $pkg. Установка зависимостей Alt Linux:"
    warn "sudo $PKGMGR $DEPS"
    read -p "Установить? (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || error "Установите зависимости вручную"
    sudo $PKGMGR $DEPS
  }
done

# Остановка старого сервиса
sudo systemctl stop zapret 2>/dev/null || true
sudo systemctl disable zapret 2>/dev/null || true

# Скачивание и установка
cd /tmp
rm -rf zapret
git clone --depth 1 https://github.com/bol-van/zapret.git
sudo rm -rf /opt/zapret
sudo mv zapret /opt/
cd /opt/zapret

log "Компиляция для systemd + nftables..."
sudo make clean systemd || error "Ошибка компиляции. Проверьте dev-пакеты"

# Запуск install_easy (интерактивно)
echo "nftables" | sudo ./install_easy.sh || warn "install_easy.sh завершился с предупреждениями"

# Конфигурация
sudo tee /opt/zapret/config > /dev/null << 'EOF'
FWTYPE=nftables
SET_MAXELEM=522288
IPSET_OPT="hashsize 262144 maxelem $SET_MAXELEM"
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
NFQWS_TCP_PKT_OUT=$((6+$AUTOHOSTLIST_RETRANS_THRESHOLD))
NFQWS_TCP_PKT_IN=3
NFQWS_UDP_PKT_OUT=$((6+$AUTOHOSTLIST_RETRANS_THRESHOLD))
NFQWS_UDP_PKT_IN=0
NFQWS_OPT="
--filter-udp=443 --hostlist="/opt/zapret/ipset/zapret-hosts-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="/opt/zapret/files/fake/quic_initial_www_google_com.bin" --new ^
--filter-udp=50000-65535  --dpi-desync=fake --dpi-desync-any-protocol --dpi-desync-cutoff=d3 --dpi-desync-repeats=6 --new ^
--filter-tcp=80 --hostlist="/opt/zapret/ipset/zapret-hosts-user.txt" --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new ^
--filter-tcp=443 --hostlist="/opt/zapret/ipset/zapret-hosts-user.txt" --dpi-desync=fake,split --dpi-desync-autottl=2 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls="/opt/zapret/files/fake/tls_clienthello_www_google_com.bin""
MODE_FILTER=autohostlist
FLOWOFFLOAD=auto
INIT_APPLY_FW=1
DISABLE_IPV6=1
EOF

# Домены для обхода
sudo mkdir -p /opt/zapret/ipset
sudo tee /opt/zapret/ipset/zapret-hosts-user.txt > /dev/null << 'EOF'
youtube.com
googlevideo.com
google.com
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
igcdn-photos-e-a.akamaihd.net
instagramstatic.com
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
rutor.info
rutor.is
nnmclub.to
rutracker.org
rutracker.cc
discord.com
discord.co
discord.app
discord.gg
discord.dev
discord.new
discordapp.com
discordapp.io
discordapp.net
discordcdn.com
discordstatus.com
discord.media
dis.gd
discord-attachments-uploads-prd.storage.googleapis.com

EOF

# Systemd unit (ваш)
sudo tee /etc/systemd/system/zapret.service > /dev/null << 'EOF'
[Unit]
Description=Zapret DPI bypass
After=network-online.target nftables.service
Wants=network-online.target nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/zapret
ExecStart=/opt/zapret/init.d/sysv/zapret start
ExecStop=/opt/zapret/init.d/sysv/zapret stop
ExecReload=/opt/zapret/init.d/sysv/zapret restart
TimeoutStartSec=60
TimeoutStopSec=60
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF

# Активация
sudo systemctl daemon-reload
sudo systemctl enable --now zapret.service
sudo /opt/zapret/ipset/get_user.sh

log "✅ Zapret установлен для Alt Linux!"
log "📁 Конфиг: /opt/zapret/config"
log "📝 Домены: /opt/zapret/ipset/zapret-hosts-user.txt"
echo "🔄 sudo systemctl restart zapret"
echo
sudo systemctl status zapret --no-pager
