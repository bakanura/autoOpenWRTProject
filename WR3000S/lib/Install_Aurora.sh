#!/bin/sh

Install_Aurora() {
    ssh "$ROUTER_USER@$ROUTER_IP" <<'EOF'
set -e

echo "[INFO] Installing Aurora LuCI theme..."

apk update

apk add luci-app-aurora-config luci-theme-aurora

uci set luci.main.mediaurlbase='/luci-static/aurora'
uci commit luci

echo "[OK] Aurora LuCI theme installed."
EOF
}
