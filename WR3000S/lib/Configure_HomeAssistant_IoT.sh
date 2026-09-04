#!/bin/sh

Configure_HomeAssistant_IoT() {
    Print_Info "Configuring isolated IoT network and Home Assistant discovery..."

    Apk_Add avahi-nodbus-daemon ||
        Fail_With_Message "Failed to install avahi-nodbus-daemon."

    local remote_script
    remote_script="$(mktemp)"

    cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -u

die() { echo "ERROR: $*" >&2; exit 1; }

: "${IOT_WIFI_SSID:?Missing IOT_WIFI_SSID}"
: "${IOT_WIFI_PASSWORD:?Missing IOT_WIFI_PASSWORD}"
: "${HOME_ASSISTANT_IP:?Missing HOME_ASSISTANT_IP}"

# Stable named sections make reruns reconcile instead of accumulating duplicates.
uci set network.iot='interface' || die "Could not create IoT interface"
uci set network.iot.proto='static'
uci set network.iot.ipaddr='192.168.9.1'
uci set network.iot.netmask='255.255.255.0'

uci set dhcp.iot='dhcp' || die "Could not create IoT DHCP scope"
uci set dhcp.iot.interface='iot'
uci set dhcp.iot.start='100'
uci set dhcp.iot.limit='150'
uci set dhcp.iot.leasetime='12h'

# Migrate an older anonymous IoT AP instead of creating a duplicate. This also
# preserves the proven phy0-ap1 runtime interface name on a normal fresh setup.
for wifi_section in $(uci show wireless 2>/dev/null | sed -n 's/^wireless\.\([^.=]*\)=wifi-iface$/\1/p'); do
    [ "$wifi_section" = 'iot_ap' ] && continue
    [ "$(uci -q get "wireless.$wifi_section.network")" = 'iot' ] || continue
    uci -q delete "wireless.$wifi_section"
done

uci set wireless.iot_ap='wifi-iface' || die "Could not create IoT Wi-Fi"
uci set wireless.iot_ap.device='radio0'
uci set wireless.iot_ap.mode='ap'
uci set wireless.iot_ap.disabled='0'
uci set wireless.iot_ap.network='iot'
uci set wireless.iot_ap.ssid="$IOT_WIFI_SSID"
# Match the proven router and retain compatibility with WPA2-only IoT devices.
uci set wireless.iot_ap.encryption='psk2'
uci set wireless.iot_ap.key="$IOT_WIFI_PASSWORD"
uci -q delete wireless.iot_ap.macfilter
uci -q delete wireless.iot_ap.maclist

uci set firewall.iot='zone' || die "Could not create IoT firewall zone"
uci set firewall.iot.name='iot'
uci set firewall.iot.network='iot'
uci set firewall.iot.input='REJECT'
uci set firewall.iot.output='ACCEPT'
uci set firewall.iot.forward='REJECT'
uci -q delete firewall.iot.masq

uci set firewall.iot_dns_dhcp='rule'
uci set firewall.iot_dns_dhcp.name='Allow-IoT-DNS'
uci set firewall.iot_dns_dhcp.src='iot'
uci set firewall.iot_dns_dhcp.proto='tcp udp'
uci set firewall.iot_dns_dhcp.dest_port='53'
uci set firewall.iot_dns_dhcp.target='ACCEPT'

uci set firewall.iot_dhcp='rule'
uci set firewall.iot_dhcp.name='Allow-IoT-DHCP'
uci set firewall.iot_dhcp.src='iot'
uci set firewall.iot_dhcp.proto='udp'
uci set firewall.iot_dhcp.dest_port='67 68'
uci set firewall.iot_dhcp.target='ACCEPT'

uci set firewall.iot_block_management='rule'
uci set firewall.iot_block_management.name='Block-IoT-Router-Management'
uci set firewall.iot_block_management.src='iot'
uci set firewall.iot_block_management.proto='tcp'
uci set firewall.iot_block_management.dest_port='22 80 443 8080'
uci set firewall.iot_block_management.target='REJECT'

# Preserve the healthy router's one-way management path. This permits LAN
# clients to initiate connections to IoT, but grants IoT no forwarding path.
uci set firewall.lan_to_iot='forwarding'
uci set firewall.lan_to_iot.src='lan'
uci set firewall.lan_to_iot.dest='iot'

# Remove only legacy global IoT forwardings. Privileged access is per-device.
for forwarding_section in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=forwarding$/\1/p'); do
    [ "$(uci -q get "firewall.$forwarding_section.src")" = 'iot' ] || continue
    forwarding_dest="$(uci -q get "firewall.$forwarding_section.dest")"
    case "$forwarding_dest" in wan|lan) uci -q delete "firewall.$forwarding_section" ;; esac
done

uci commit network || die "Could not commit network configuration"
uci commit dhcp || die "Could not commit DHCP configuration"
uci commit wireless || die "Could not commit wireless configuration"
fw4 check || die "Firewall validation failed"
uci commit firewall || die "Could not commit firewall configuration"

mkdir -p /etc/avahi || die "Could not create Avahi configuration directory"
cat > /etc/avahi/avahi-daemon.conf <<'AVAHI'
[server]
allow-interfaces=br-lan,phy0-ap1
#host-name=foo
#domain-name=local
use-ipv4=yes
use-ipv6=yes
check-response-ttl=no
use-iff-running=no

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=no
publish-domain=yes
#publish-dns-servers=192.168.1.1
#publish-resolv-conf-dns-servers=yes

[reflector]
enable-reflector=yes
reflect-ipv=no

[rlimits]
#rlimit-as=
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=30
rlimit-stack=4194304
rlimit-nproc=3
AVAHI

cat > /usr/sbin/homeassistant-iot <<'HELPER'
#!/bin/sh
set -u

DEFAULT_HOME_ASSISTANT_IP='__HOME_ASSISTANT_IP__'
HOME_ASSISTANT_PORT='8123'

die() { echo "ERROR: $*" >&2; exit 1; }
usage() {
    echo "Usage: homeassistant-iot add -Name NAME -Mac AA:BB:CC:DD:EE:FF [-HomeAssistant IPv4] [-internet true|false]" >&2
    echo "       homeassistant-iot internet -Name NAME true|false" >&2
    echo "       homeassistant-iot remove -Name NAME" >&2
    exit 2
}
valid_ipv4() {
    old_ifs=$IFS; IFS=.; set -- $1; IFS=$old_ifs
    [ "$#" -eq 4 ] || return 1
    for octet in "$@"; do
        case "$octet" in ''|*[!0-9]*) return 1 ;; esac
        [ "$octet" -le 255 ] 2>/dev/null || return 1
    done
}
valid_name() {
    [ -n "$1" ] || return 1
    case "$1" in *[!A-Za-z0-9_.-]*) return 1 ;; esac
}
find_host_by_mac() {
    FOUND_HOST=''
    for candidate in $(uci show dhcp 2>/dev/null | sed -n 's/^dhcp\.\([^.=]*\)=host$/\1/p'); do
        candidate_mac="$(uci -q get "dhcp.$candidate.mac" | tr '[:lower:]' '[:upper:]')"
        if [ "$candidate_mac" = "$DEVICE_MAC" ]; then FOUND_HOST=$candidate; return 0; fi
    done
    return 1
}
find_host_by_name() {
    FOUND_HOST=''
    for candidate in $(uci show dhcp 2>/dev/null | sed -n 's/^dhcp\.\([^.=]*\)=host$/\1/p'); do
        if [ "$(uci -q get "dhcp.$candidate.name")" = "$DEVICE_NAME" ]; then FOUND_HOST=$candidate; return 0; fi
    done
    return 1
}
find_rule_by_name() {
    FOUND_RULE=''
    for candidate in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=rule$/\1/p'); do
        if [ "$(uci -q get "firewall.$candidate.name")" = "$1" ]; then FOUND_RULE=$candidate; return 0; fi
    done
    return 1
}
cleanup_created() {
    [ -z "${CREATED_HA-}" ] || uci -q delete "firewall.$CREATED_HA"
    [ -z "${CREATED_MDNS-}" ] || uci -q delete "firewall.$CREATED_MDNS"
    [ -z "${CREATED_INTERNET-}" ] || uci -q delete "firewall.$CREATED_INTERNET"
    [ -z "${CREATED_DHCP-}" ] || uci -q delete "dhcp.$CREATED_DHCP"
}

ACTION="${1-}"; [ -n "$ACTION" ] || usage; shift
DEVICE_NAME=''; DEVICE_MAC=''; HA_IP="$DEFAULT_HOME_ASSISTANT_IP"; INTERNET_ACCESS='false'; INTERNET_SETTING=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        -Name|--name) [ "$#" -ge 2 ] || usage; DEVICE_NAME=$2; shift 2 ;;
        -Mac|--mac) [ "$#" -ge 2 ] || usage; DEVICE_MAC=$2; shift 2 ;;
        -HomeAssistant|--homeassistant|--ha) [ "$#" -ge 2 ] || usage; HA_IP=$2; shift 2 ;;
        -internet|--internet) [ "$#" -ge 2 ] || usage; INTERNET_ACCESS=$2; shift 2 ;;
        true|false)
            [ "$ACTION" = 'internet' ] && [ -z "$INTERNET_SETTING" ] || usage
            INTERNET_SETTING=$1
            shift
            ;;
        *) usage ;;
    esac
done
valid_name "$DEVICE_NAME" || die "Device name must use only letters, digits, dot, underscore, or hyphen"
valid_ipv4 "$HA_IP" || die "Invalid Home Assistant IPv4 address: $HA_IP"
case "$INTERNET_ACCESS" in true|false) ;; *) die "-internet must be true or false" ;; esac

HA_RULE_NAME="${DEVICE_NAME}-IoT-HAOS01"
MDNS_RULE_NAME="${DEVICE_NAME}-IoT-mDNS-to-Avahi"
INTERNET_RULE_NAME="${DEVICE_NAME}-IoT-Internet"

case "$ACTION" in
add)
    [ -n "$DEVICE_MAC" ] || die "-Mac is required for add"
    DEVICE_MAC="$(printf '%s' "$DEVICE_MAC" | tr '[:lower:]' '[:upper:]')"
    echo "$DEVICE_MAC" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || die "Invalid MAC address: $DEVICE_MAC"
    find_rule_by_name "$HA_RULE_NAME" && die "Firewall rule already exists: $HA_RULE_NAME"
    find_rule_by_name "$MDNS_RULE_NAME" && die "Firewall rule already exists: $MDNS_RULE_NAME"

    [ "$INTERNET_ACCESS" = 'false' ] || ! find_rule_by_name "$INTERNET_RULE_NAME" || die "Firewall rule already exists: $INTERNET_RULE_NAME"

    CREATED_DHCP=''; CREATED_HA=''; CREATED_MDNS=''; CREATED_INTERNET=''
    if find_host_by_mac; then
        [ "$(uci -q get "dhcp.$FOUND_HOST.name")" = "$DEVICE_NAME" ] || die "MAC is reserved for a different device"
        DEVICE_IP="$(uci -q get "dhcp.$FOUND_HOST.ip")"
    else
        if find_host_by_name; then die "Device name is reserved for a different MAC"; fi
        DEVICE_IP="$(awk -v mac="$DEVICE_MAC" 'toupper($2)==mac {print $3; exit}' /tmp/dhcp.leases)"
        [ -n "$DEVICE_IP" ] || die "No current DHCP lease found for $DEVICE_MAC"
        case "$DEVICE_IP" in 192.168.9.*) ;; *) die "Lease $DEVICE_IP is not in the IoT subnet" ;; esac
        CREATED_DHCP="$(uci add dhcp host)" || die "Could not create DHCP reservation"
        uci set "dhcp.$CREATED_DHCP.name=$DEVICE_NAME"
        uci set "dhcp.$CREATED_DHCP.mac=$DEVICE_MAC"
        uci set "dhcp.$CREATED_DHCP.ip=$DEVICE_IP"
    fi
    if ! valid_ipv4 "$DEVICE_IP"; then cleanup_created; die "Reservation has invalid IPv4 address: $DEVICE_IP"; fi
    case "$DEVICE_IP" in 192.168.9.0|192.168.9.255) cleanup_created; die "Reservation uses an unusable IoT address: $DEVICE_IP" ;; 192.168.9.*) ;; *) cleanup_created; die "Reservation $DEVICE_IP is not in the IoT subnet" ;; esac

    CREATED_HA="$(uci add firewall rule)" || { cleanup_created; die "Could not create HA rule"; }
    uci set "firewall.$CREATED_HA.name=$HA_RULE_NAME"
    uci set "firewall.$CREATED_HA.src=iot"
    uci set "firewall.$CREATED_HA.src_ip=$DEVICE_IP"
    uci set "firewall.$CREATED_HA.src_mac=$DEVICE_MAC"
    uci set "firewall.$CREATED_HA.dest=lan"
    uci set "firewall.$CREATED_HA.dest_ip=$HA_IP"
    uci set "firewall.$CREATED_HA.proto=tcp"
    uci set "firewall.$CREATED_HA.dest_port=$HOME_ASSISTANT_PORT"
    uci set "firewall.$CREATED_HA.target=ACCEPT"

    CREATED_MDNS="$(uci add firewall rule)" || { cleanup_created; die "Could not create mDNS rule"; }
    uci set "firewall.$CREATED_MDNS.name=$MDNS_RULE_NAME"
    uci set "firewall.$CREATED_MDNS.src=iot"
    uci set "firewall.$CREATED_MDNS.src_ip=$DEVICE_IP"
    uci set "firewall.$CREATED_MDNS.src_mac=$DEVICE_MAC"
    uci set "firewall.$CREATED_MDNS.proto=udp"
    uci set "firewall.$CREATED_MDNS.dest_ip=224.0.0.251"
    uci set "firewall.$CREATED_MDNS.dest_port=5353"
    uci set "firewall.$CREATED_MDNS.target=ACCEPT"

    if [ "$INTERNET_ACCESS" = 'true' ]; then
        CREATED_INTERNET="$(uci add firewall rule)" || { cleanup_created; die "Could not create internet rule"; }
        uci set "firewall.$CREATED_INTERNET.name=$INTERNET_RULE_NAME"
        uci set "firewall.$CREATED_INTERNET.src=iot"
        uci set "firewall.$CREATED_INTERNET.src_ip=$DEVICE_IP"
        uci set "firewall.$CREATED_INTERNET.src_mac=$DEVICE_MAC"
        uci set "firewall.$CREATED_INTERNET.dest=wan"
        uci set "firewall.$CREATED_INTERNET.target=ACCEPT"
    fi

    if ! fw4 check; then cleanup_created; die "Firewall validation failed; new sections were removed"; fi
    uci commit dhcp || { cleanup_created; die "Could not commit DHCP reservation"; }
    uci commit firewall || die "Could not commit firewall rules"
    /etc/init.d/dnsmasq reload || die "Could not reload dnsmasq"
    /etc/init.d/firewall reload || die "Could not reload firewall"
    fw4 check || die "Firewall validation failed after reload"
    printf 'SUCCESS\n  %s\n  %s -> %s\n  HA:       %s -> %s:%s/tcp\n  mDNS:     %s -> Avahi/5353\n  Internet: %s\n' "$DEVICE_NAME" "$DEVICE_MAC" "$DEVICE_IP" "$DEVICE_IP" "$HA_IP" "$HOME_ASSISTANT_PORT" "$DEVICE_IP" "$INTERNET_ACCESS"
    ;;
internet)
    [ -n "$INTERNET_SETTING" ] || die "Specify true or false after the device name"
    find_host_by_name || die "No managed DHCP reservation found for $DEVICE_NAME"
    DEVICE_IP="$(uci -q get "dhcp.$FOUND_HOST.ip")"
    DEVICE_MAC="$(uci -q get "dhcp.$FOUND_HOST.mac" | tr '[:lower:]' '[:upper:]')"
    valid_ipv4 "$DEVICE_IP" || die "Reservation has invalid IPv4 address: $DEVICE_IP"
    case "$DEVICE_IP" in 192.168.9.0|192.168.9.255) die "Reservation uses an unusable IoT address: $DEVICE_IP" ;; 192.168.9.*) ;; *) die "Reservation $DEVICE_IP is not in the IoT subnet" ;; esac
    echo "$DEVICE_MAC" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || die "Reservation has invalid MAC address: $DEVICE_MAC"

    if [ "$INTERNET_SETTING" = 'true' ]; then
        if find_rule_by_name "$INTERNET_RULE_NAME"; then
            INTERNET_RULE=$FOUND_RULE
        else
            INTERNET_RULE="$(uci add firewall rule)" || die "Could not create internet rule"
        fi
        uci set "firewall.$INTERNET_RULE.name=$INTERNET_RULE_NAME"
        uci set "firewall.$INTERNET_RULE.src=iot"
        uci set "firewall.$INTERNET_RULE.src_ip=$DEVICE_IP"
        uci set "firewall.$INTERNET_RULE.src_mac=$DEVICE_MAC"
        uci set "firewall.$INTERNET_RULE.dest=wan"
        uci set "firewall.$INTERNET_RULE.target=ACCEPT"
    else
        find_rule_by_name "$INTERNET_RULE_NAME" && uci -q delete "firewall.$FOUND_RULE"
    fi

    fw4 check || die "Firewall validation failed; changes were not committed"
    uci commit firewall || die "Could not commit internet access change"
    /etc/init.d/firewall reload || die "Could not reload firewall"
    fw4 check || die "Firewall validation failed after reload"
    echo "SUCCESS: internet access for $DEVICE_NAME is $INTERNET_SETTING"
    ;;
remove)
    find_rule_by_name "$HA_RULE_NAME" && { echo "Removing firewall rule: $HA_RULE_NAME"; uci -q delete "firewall.$FOUND_RULE"; }
    find_rule_by_name "$MDNS_RULE_NAME" && { echo "Removing firewall rule: $MDNS_RULE_NAME"; uci -q delete "firewall.$FOUND_RULE"; }
    find_rule_by_name "$INTERNET_RULE_NAME" && { echo "Removing firewall rule: $INTERNET_RULE_NAME"; uci -q delete "firewall.$FOUND_RULE"; }
    find_host_by_name && { echo "Removing DHCP reservation: $FOUND_HOST"; uci -q delete "dhcp.$FOUND_HOST"; }
    fw4 check || die "Firewall validation failed; changes were not committed"
    uci commit firewall || die "Could not commit firewall removal"
    uci commit dhcp || die "Could not commit DHCP removal"
    /etc/init.d/dnsmasq reload || die "Could not reload dnsmasq"
    /etc/init.d/firewall reload || die "Could not reload firewall"
    fw4 check || die "Firewall validation failed after reload"
    echo "SUCCESS: removed $DEVICE_NAME"
    ;;
*) usage ;;
esac
HELPER

sed -i "s/__HOME_ASSISTANT_IP__/$HOME_ASSISTANT_IP/" /usr/sbin/homeassistant-iot || die "Could not set HA default"
chmod 0755 /usr/sbin/homeassistant-iot || die "Could not make helper executable"

/etc/init.d/avahi-daemon enable || die "Could not enable Avahi"
/etc/init.d/avahi-daemon restart || die "Could not restart Avahi"
/etc/init.d/network reload || die "Could not reload network"
/etc/init.d/dnsmasq reload || die "Could not reload dnsmasq"
/etc/init.d/firewall reload || die "Could not reload firewall"
wifi reload || die "Could not reload Wi-Fi"
fw4 check || die "Final firewall validation failed"
REMOTE

    if ! Router_Ssh \
        "IOT_WIFI_SSID=$(Shell_Quote "$IOT_WIFI_SSID") \
         IOT_WIFI_PASSWORD=$(Shell_Quote "$IOT_WIFI_PASSWORD") \
         HOME_ASSISTANT_IP=$(Shell_Quote "$HOME_ASSISTANT_IP") \
         sh -s" < "$remote_script"; then
        rm -f "$remote_script"
        Fail_With_Message "Failed to configure Home Assistant IoT integration."
    fi

    rm -f "$remote_script"
    Print_Success "Isolated IoT network and Home Assistant helper configured."
}
