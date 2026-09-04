#!/bin/sh

Configure_Tailscale_Routes() {
    (( INSTALL_TAILSCALE == 1 )) || return 0
    Print_Info "Configuring Tailscale networking..."

    Router_Ssh \
        "INSTALL_TAILSCALE_ROUTES=$(Shell_Quote "$INSTALL_TAILSCALE_ROUTES") \
         INSTALL_TAILSCALE_LAN_ACCESS=$(Shell_Quote "$INSTALL_TAILSCALE_LAN_ACCESS") \
         ALLOW_TAILSCALE_ROUTER_MANAGEMENT=$(Shell_Quote "$ALLOW_TAILSCALE_ROUTER_MANAGEMENT") \
         ENABLE_TAILSCALE_REMOTE_ROUTERS=$(Shell_Quote "$ENABLE_TAILSCALE_REMOTE_ROUTERS") \
         LAN_NET=$(Shell_Quote "$LAN_NET") sh -s" <<'REMOTE'
set -u
die() { echo "ERROR: $*" >&2; exit 1; }

# Remove sections accumulated by older installer revisions, using stable UCI
# identifiers so anonymous-index shifting cannot delete unrelated entries.
for old_section in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=zone$/\1/p'); do
    [ "$old_section" = 'tailscale' ] && continue
    [ "$(uci -q get "firewall.$old_section.name")" = 'tailscale' ] && uci -q delete "firewall.$old_section"
done
for old_section in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p'); do
    [ "$old_section" = 'lan_to_tailscale' ] && continue
    [ "$old_section" = 'tailscale_to_lan' ] && continue
    old_src="$(uci -q get "firewall.$old_section.src")"
    old_dest="$(uci -q get "firewall.$old_section.dest")"
    case "$old_src:$old_dest" in lan:tailscale|tailscale:lan) uci -q delete "firewall.$old_section" ;; esac
done

# Undo exact legacy changes made by the old implementation.
sed -i '/^net\.ipv4\.conf\.all\.rp_filter=0$/d' /etc/sysctl.conf
sysctl -w net.ipv4.conf.all.rp_filter=1 >/dev/null 2>&1 || true
if [ -f /etc/rc.local ]; then
    sed -i '\|^nft insert rule inet fw4 output oifname "tailscale0" accept 2>/dev/null$|d' /etc/rc.local
    sed -i '/^ip route replace .* table 52 2>\/dev\/null || true$/d' /etc/rc.local
    sed -i '/^ip rule add .* lookup 52 .*2>\/dev\/null || true$/d' /etc/rc.local
fi

if [ "$INSTALL_TAILSCALE_ROUTES" = '1' ]; then
    tailscale set --advertise-routes="$LAN_NET" || die "Could not advertise LAN route"
fi
if [ "$ENABLE_TAILSCALE_REMOTE_ROUTERS" = '1' ]; then
    tailscale set --accept-routes=true || die "Could not enable accepted routes"
else
    tailscale set --accept-routes=false || die "Could not disable accepted routes"
fi

if [ "$INSTALL_TAILSCALE_LAN_ACCESS" = '1' ]; then
    uci set network.tailscale='interface'
    uci set network.tailscale.proto='none'
    uci set network.tailscale.device='tailscale0'
    uci set firewall.tailscale='zone'
    uci set firewall.tailscale.name='tailscale'
    uci set firewall.tailscale.network='tailscale'
    if [ "$ALLOW_TAILSCALE_ROUTER_MANAGEMENT" = '1' ]; then
        uci set firewall.tailscale.input='ACCEPT'
        # Dropbear's LAN-only binding would otherwise make the explicit
        # management choice ineffective. WAN/IoT remain protected by zones.
        uci -q delete dropbear.@dropbear[0].Interface
    else
        uci set firewall.tailscale.input='REJECT'
        uci set dropbear.@dropbear[0].Interface='lan'
    fi
    uci set firewall.tailscale.output='ACCEPT'
    uci set firewall.tailscale.forward='ACCEPT'
    uci set firewall.tailscale.masq='1'
    uci set firewall.lan_to_tailscale='forwarding'
    uci set firewall.lan_to_tailscale.src='lan'
    uci set firewall.lan_to_tailscale.dest='tailscale'
    uci set firewall.tailscale_to_lan='forwarding'
    uci set firewall.tailscale_to_lan.src='tailscale'
    uci set firewall.tailscale_to_lan.dest='lan'
    grep -qxF 'net.ipv4.conf.tailscale0.rp_filter=0' /etc/sysctl.conf ||
        echo 'net.ipv4.conf.tailscale0.rp_filter=0' >> /etc/sysctl.conf
    sysctl -w net.ipv4.conf.tailscale0.rp_filter=0 >/dev/null 2>&1 || true
else
    uci -q delete firewall.lan_to_tailscale
    uci -q delete firewall.tailscale_to_lan
    uci -q delete firewall.tailscale
    uci -q delete network.tailscale
    uci set dropbear.@dropbear[0].Interface='lan'
fi

uci commit network || die "Could not commit Tailscale network"
fw4 check || die "Tailscale firewall validation failed"
uci commit firewall || die "Could not commit Tailscale firewall"
uci commit dropbear || die "Could not commit Dropbear binding"
/etc/init.d/network reload || die "Could not reload network"
/etc/init.d/firewall reload || die "Could not reload firewall"
/etc/init.d/dropbear restart || die "Could not restart Dropbear"
fw4 check || die "Tailscale firewall failed after reload"
REMOTE

    Print_Success "Tailscale networking configured with stable UCI sections."
}
