#!/usr/bin/env bash
# =============================================================
#  OSRP | Osijek Roleplay - 24/7 server installer (Linux VPS)
#  Ubuntu 22.04 / 24.04 or Debian 12, x86_64 (Intel/AMD)
#
#  Install:  curl -fsSL https://raw.githubusercontent.com/jakov543/Osrp/main/server/linux/install-osrp.sh | sudo bash
#  Update:   sudo bash /opt/osrp/repo/server/linux/install-osrp.sh update
# =============================================================
set -euo pipefail

OSRP_DIR=/opt/osrp
REPO_URL=https://github.com/jakov543/Osrp
ART_DIR=$OSRP_DIR/artifacts
DATA_DIR=$OSRP_DIR/server-data
RES_DIR=$DATA_DIR/resources
SERVICE=osrp

green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1;36m>> %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m[OSRP] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Pokreni sa sudo (root)."
[ "$(uname -m)" = "x86_64" ] || fail "FiveM server radi samo na x86_64 (Intel/AMD). ARM serveri (npr. Oracle Ampere) nisu podrzani."
command -v apt-get >/dev/null || fail "Treba Ubuntu ili Debian (apt-get)."

copy_osrp_resources() {
    step "Kopiram OSRP resurse"
    mkdir -p "$RES_DIR/[osrp]"
    cp -a "$OSRP_DIR/repo/fivem-resources/." "$RES_DIR/[osrp]/"
    chown -R osrp:osrp "$OSRP_DIR"
}

# ---------- update mode ----------
if [ "${1:-}" = "update" ]; then
    step "Preuzimam najnoviji OSRP s GitHuba"
    runuser -u osrp -- git -C "$OSRP_DIR/repo" pull --ff-only
    copy_osrp_resources
    systemctl restart "$SERVICE"
    green "OSRP azuriran i ponovno pokrenut."
    exit 0
fi

green "========================================="
green "   OSRP | Osijek Roleplay - 24/7 setup"
green "========================================="

step "Instaliram potrebne pakete"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl xz-utils git ca-certificates >/dev/null

step "Kreiram korisnika 'osrp'"
id osrp >/dev/null 2>&1 || useradd --system --create-home --home-dir "$OSRP_DIR" --shell /usr/sbin/nologin osrp
mkdir -p "$ART_DIR" "$RES_DIR"

step "Preuzimam FXServer (sluzbeni Linux server)"
if [ ! -x "$ART_DIR/run.sh" ]; then
    URL=$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server \
          | grep -o '"recommended_download":"[^"]*"' | cut -d'"' -f4 || true)
    if [ -z "$URL" ]; then
        echo "Nisam mogao naci verziju automatski."
        echo "Otvori https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
        echo "i kopiraj link na 'LATEST RECOMMENDED' fx.tar.xz"
        read -r -p "Zalijepi link: " URL < /dev/tty
    fi
    curl -fL --progress-bar "$URL" -o /tmp/fx.tar.xz
    tar -xf /tmp/fx.tar.xz -C "$ART_DIR"
    rm -f /tmp/fx.tar.xz
fi
[ -f "$ART_DIR/run.sh" ] || fail "FXServer nije raspakiran."

step "Preuzimam OSRP s GitHuba"
if [ -d "$OSRP_DIR/repo/.git" ]; then runuser -u osrp -- git -C "$OSRP_DIR/repo" pull --ff-only
else git clone --depth 1 "$REPO_URL" "$OSRP_DIR/repo"; fi

step "Preuzimam osnovne resurse (chat, sessionmanager)"
if [ ! -d "$RES_DIR/[system]" ]; then
    rm -rf /tmp/cfx-server-data
    git clone --depth 1 https://github.com/citizenfx/cfx-server-data /tmp/cfx-server-data
    cp -a /tmp/cfx-server-data/resources/. "$RES_DIR/"
    rm -rf /tmp/cfx-server-data
fi

copy_osrp_resources

step "server.cfg"
CFG="$DATA_DIR/server.cfg"
if [ ! -f "$CFG" ]; then
    KEY="${OSRP_KEY:-}"
    if [ -z "$KEY" ]; then
        echo "Treba ti BESPLATNI server kljuc: https://portal.cfx.re -> Server Keys -> Generate"
        echo "(IP = javni IP ovog servera)"
    fi
    while ! printf '%s' "$KEY" | grep -q '^cfxk_'; do
        read -r -p "Zalijepi kljuc (cfxk_...): " KEY < /dev/tty
        KEY=$(printf '%s' "$KEY" | tr -d '[:space:]')
    done
    sed "s|__LICENSE_KEY__|$KEY|" "$OSRP_DIR/repo/server/server.cfg.template" > "$CFG"
else
    echo "server.cfg vec postoji - ostavljam ga."
fi
chown -R osrp:osrp "$OSRP_DIR"

step "Postavljam 24/7 servis (auto start + auto restart)"
cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=OSRP | Osijek Roleplay FiveM server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=osrp
WorkingDirectory=$DATA_DIR
ExecStart=/bin/bash $ART_DIR/run.sh +exec server.cfg
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$SERVICE"

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    step "Otvaram port 30120 u firewallu"
    ufw allow 30120/tcp >/dev/null
    ufw allow 30120/udp >/dev/null
fi

IP=$(curl -fsSL https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
green ""
green "========================================="
green "  OSRP radi 24/7!"
green "  Adresa za launcher:  $IP:30120"
green "========================================="
echo "Konzola / logovi:      journalctl -u $SERVICE -f"
echo "Restart:               systemctl restart $SERVICE"
echo "Azuriranje OSRP-a:     sudo bash $OSRP_DIR/repo/server/linux/install-osrp.sh update"
echo "Admin: udi na server, u logovima nadi 'add_principal ...' liniju i dodaj je u $CFG, pa restart."
