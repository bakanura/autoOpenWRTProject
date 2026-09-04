#!/bin/sh

Configure_Guest() {
    Print_Info "Configuring isolated internet-only guest Wi-Fi..."

    local remote_script
    remote_script="$(mktemp)"
    cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -u
die() { echo "ERROR: $*" >&2; exit 1; }

: "${GUEST_WIFI_SSID:?Missing GUEST_WIFI_SSID}"
: "${GUEST_WIFI_PASSWORD:?Missing GUEST_WIFI_PASSWORD}"

uci set network.guest='interface' || die "Could not create guest interface"
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.10.1'
uci set network.guest.netmask='255.255.255.0'

uci set dhcp.guest='dhcp' || die "Could not create guest DHCP scope"
uci set dhcp.guest.interface='guest'
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='150'
uci set dhcp.guest.leasetime='4h'

# Remove older anonymous guest APs before reconciling the stable section.
for section in $(uci show wireless 2>/dev/null | sed -n 's/^wireless\.\([^.=]*\)=wifi-iface$/\1/p'); do
    [ "$section" = 'guest_ap' ] && continue
    [ "$(uci -q get "wireless.$section.network")" = 'guest' ] && uci -q delete "wireless.$section"
done
uci set wireless.guest_ap='wifi-iface' || die "Could not create guest Wi-Fi"
uci set wireless.guest_ap.device='radio0'
uci set wireless.guest_ap.mode='ap'
uci set wireless.guest_ap.disabled='0'
uci set wireless.guest_ap.network='guest'
uci set wireless.guest_ap.ssid="$GUEST_WIFI_SSID"
uci set wireless.guest_ap.encryption='sae-mixed'
uci set wireless.guest_ap.key="$GUEST_WIFI_PASSWORD"
uci set wireless.guest_ap.isolate='1'

uci set firewall.guest='zone' || die "Could not create guest firewall zone"
uci set firewall.guest.name='guest'
uci set firewall.guest.network='guest'
uci set firewall.guest.input='REJECT'
uci set firewall.guest.output='ACCEPT'
uci set firewall.guest.forward='REJECT'
uci -q delete firewall.guest.masq

uci set firewall.guest_dns='rule'
uci set firewall.guest_dns.name='Allow-Guest-DNS'
uci set firewall.guest_dns.src='guest'
uci set firewall.guest_dns.proto='tcp udp'
uci set firewall.guest_dns.dest_port='53'
uci set firewall.guest_dns.target='ACCEPT'

uci set firewall.guest_dhcp='rule'
uci set firewall.guest_dhcp.name='Allow-Guest-DHCP'
uci set firewall.guest_dhcp.src='guest'
uci set firewall.guest_dhcp.proto='udp'
uci set firewall.guest_dhcp.dest_port='67 68'
uci set firewall.guest_dhcp.target='ACCEPT'

uci set firewall.guest_to_wan='forwarding'
uci set firewall.guest_to_wan.src='guest'
uci set firewall.guest_to_wan.dest='wan'

# Internet is the sole forwarding destination for guest clients.
for section in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p'); do
    [ "$section" = 'guest_to_wan' ] && continue
    [ "$(uci -q get "firewall.$section.src")" = 'guest' ] && uci -q delete "firewall.$section"
done

uci commit network || die "Could not commit guest network"
uci commit dhcp || die "Could not commit guest DHCP"
uci commit wireless || die "Could not commit guest Wi-Fi"
fw4 check || die "Guest firewall validation failed"
uci commit firewall || die "Could not commit guest firewall"
/etc/init.d/network reload || die "Could not reload network"
/etc/init.d/dnsmasq reload || die "Could not reload DHCP/DNS"
/etc/init.d/firewall reload || die "Could not reload firewall"
wifi reload || die "Could not reload Wi-Fi"
fw4 check || die "Guest firewall validation failed after reload"
REMOTE

    if ! Router_Ssh \
        "GUEST_WIFI_SSID=$(Shell_Quote "$GUEST_WIFI_SSID") \
         GUEST_WIFI_PASSWORD=$(Shell_Quote "$GUEST_WIFI_PASSWORD") \
         sh -s" < "$remote_script"; then
        rm -f "$remote_script"
        Fail_With_Message "Failed to configure guest Wi-Fi."
    fi
    rm -f "$remote_script"
    Print_Success "Guest Wi-Fi configured with internet-only access and client isolation."
}
