#!/bin/sh

Configure_AdGuardHome() {
    (( INSTALL_ADGUARD_HOME == 1 )) || {
        Print_Info "AdGuard Home installation skipped."
        return 0
    }

    Print_Info "Installing and configuring AdGuard Home..."
    Apk_Add adguardhome || Fail_With_Message "Failed to install AdGuard Home."

    local remote_script
    remote_script="$(mktemp)"
    cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -u
die() { echo "ERROR: $*" >&2; exit 1; }
json_escape() { printf '%s' "$1" | awk '{gsub(/\\/, "\\\\"); gsub(/\"/, "\\\""); printf "%s", $0}'; }

: "${ROUTER_IP:?Missing ROUTER_IP}"
: "${ADGUARD_ADMIN_USER:?Missing ADGUARD_ADMIN_USER}"
: "${ADGUARD_ADMIN_PASSWORD:?Missing ADGUARD_ADMIN_PASSWORD}"
: "${ENFORCE_ADGUARD_DNS:?Missing ENFORCE_ADGUARD_DNS}"

# Keep dnsmasq as the DHCP/local-name authority, but free public port 53 for
# AdGuard. AdGuard sends .lan queries back to dnsmasq on this loopback port.
uci set dhcp.@dnsmasq[0].port='54'
uci set dhcp.@dnsmasq[0].localservice='1'
uci set dhcp.@dnsmasq[0].rebind_protection='1'
uci set dhcp.@dnsmasq[0].domainneeded='1'
uci set dhcp.@dnsmasq[0].boguspriv='1'
uci commit dhcp || die "Could not commit dnsmasq configuration"
/etc/init.d/dnsmasq restart || die "Could not move dnsmasq DNS to port 54"

# This fresh-install workflow owns AdGuard's generated YAML. Recreating only
# that file makes a rerun recover from a half-completed first-install wizard.
/etc/init.d/adguardhome stop >/dev/null 2>&1 || true
rm -f /etc/adguardhome/adguardhome.yaml
/etc/init.d/adguardhome enable || die "Could not enable AdGuard Home"
/etc/init.d/adguardhome start || die "Could not start AdGuard setup service"
sleep 2

user_json="$(json_escape "$ADGUARD_ADMIN_USER")"
password_json="$(json_escape "$ADGUARD_ADMIN_PASSWORD")"
install_json="{\"username\":\"$user_json\",\"password\":\"$password_json\",\"web\":{\"ip\":\"$ROUTER_IP\",\"port\":8080},\"dns\":{\"ip\":\"0.0.0.0\",\"port\":53},\"set_static_ip\":false}"
wget -qO- --header='Content-Type: application/json' --post-data="$install_json" \
    http://127.0.0.1:3000/control/install/configure >/dev/null ||
    die "AdGuard initial configuration failed"
sleep 2

auth="$(printf '%s:%s' "$ADGUARD_ADMIN_USER" "$ADGUARD_ADMIN_PASSWORD" | base64 | tr -d '\n')"
api_post() {
    endpoint=$1
    body=$2
    wget -qO- --header="Authorization: Basic $auth" \
        --header='Content-Type: application/json' --post-data="$body" \
        "http://$ROUTER_IP:8080/control/$endpoint"
}
api_get() {
    wget -qO- --header="Authorization: Basic $auth" \
        "http://$ROUTER_IP:8080/control/$1"
}

# Deterministic fail-closed upstream policy: no ISP resolver fallback. Quad9's
# filtered DoH endpoint adds a second malware/phishing layer; AdGuard supplies
# ad/tracker filtering and Safe Browsing.
api_post dns_config '{"upstream_dns":["https://dns.quad9.net/dns-query","[/lan/]127.0.0.1:54"],"bootstrap_dns":["9.9.9.9","149.112.112.112"],"fallback_dns":[]}' >/dev/null || die "Could not configure AdGuard DNS"
api_post filtering/config '{"enabled":true,"interval":24}' >/dev/null || die "Could not enable DNS filtering"
api_post protection '{"enabled":true}' >/dev/null || die "Could not enable AdGuard protection"
api_post safebrowsing/enable '{}' >/dev/null || die "Could not enable phishing/malware Safe Browsing"

# The official AdGuard DNS filter covers ads and trackers. Adding an existing
# URL is harmless on reruns; refresh still validates that enabled lists load.
api_post filtering/add_url '{"name":"AdGuard DNS filter","url":"https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt","whitelist":false}' >/dev/null 2>&1 || true
api_post filtering/refresh '{"whitelist":false}' >/dev/null || die "Could not refresh AdGuard filter lists"

/etc/init.d/adguardhome restart || die "Could not restart configured AdGuard Home"
sleep 2
/etc/init.d/adguardhome running || die "AdGuard Home is not running"
api_get status | grep -q '"protection_enabled":true' || die "AdGuard protection is not active"
api_get filtering/status | grep -q '"enabled":true' || die "AdGuard filtering is not active"
api_get filtering/status | grep -Fq 'AdGuard DNS filter' || die "AdGuard DNS filter is not installed"

if [ "$ENFORCE_ADGUARD_DNS" = '1' ]; then
    uci set firewall.adguard_force_lan_dns='redirect'
    uci set firewall.adguard_force_lan_dns.name='Force-LAN-DNS-Through-AdGuard'
    uci set firewall.adguard_force_lan_dns.src='lan'
    uci set firewall.adguard_force_lan_dns.proto='tcp udp'
    uci set firewall.adguard_force_lan_dns.src_dport='53'
    uci set firewall.adguard_force_lan_dns.dest_port='53'
    uci set firewall.adguard_force_lan_dns.target='DNAT'
    if uci -q get firewall.iot.name >/dev/null; then
        uci set firewall.adguard_force_iot_dns='redirect'
        uci set firewall.adguard_force_iot_dns.name='Force-IoT-DNS-Through-AdGuard'
        uci set firewall.adguard_force_iot_dns.src='iot'
        uci set firewall.adguard_force_iot_dns.proto='tcp udp'
        uci set firewall.adguard_force_iot_dns.src_dport='53'
        uci set firewall.adguard_force_iot_dns.dest_port='53'
        uci set firewall.adguard_force_iot_dns.target='DNAT'
    fi
    if uci -q get firewall.guest.name >/dev/null; then
        uci set firewall.adguard_force_guest_dns='redirect'
        uci set firewall.adguard_force_guest_dns.name='Force-Guest-DNS-Through-AdGuard'
        uci set firewall.adguard_force_guest_dns.src='guest'
        uci set firewall.adguard_force_guest_dns.proto='tcp udp'
        uci set firewall.adguard_force_guest_dns.src_dport='53'
        uci set firewall.adguard_force_guest_dns.dest_port='53'
        uci set firewall.adguard_force_guest_dns.target='DNAT'
    fi
else
    uci -q delete firewall.adguard_force_lan_dns
    uci -q delete firewall.adguard_force_iot_dns
    uci -q delete firewall.adguard_force_guest_dns
fi
fw4 check || die "AdGuard DNS redirect firewall validation failed"
uci commit firewall || die "Could not commit AdGuard DNS redirects"
/etc/init.d/firewall reload || die "Could not reload AdGuard DNS redirects"

# Confirm the intended listeners without depending on ss/netstat packages.
nslookup openwrt.org 127.0.0.1 >/dev/null 2>&1 || die "AdGuard DNS resolution test failed"
REMOTE

    if ! Router_Ssh \
        "ROUTER_IP=$(Shell_Quote "$ROUTER_NEW") \
         ADGUARD_ADMIN_USER=$(Shell_Quote "$ADGUARD_ADMIN_USER") \
         ADGUARD_ADMIN_PASSWORD=$(Shell_Quote "$ADGUARD_ADMIN_PASSWORD") \
         ENFORCE_ADGUARD_DNS=$(Shell_Quote "$ENFORCE_ADGUARD_DNS") \
         sh -s" < "$remote_script"; then
        rm -f "$remote_script"
        Fail_With_Message "AdGuard Home setup failed."
    fi
    rm -f "$remote_script"
    Print_Success "AdGuard Home is filtering ads, trackers, phishing, and malware domains."
}
