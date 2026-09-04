#!/bin/sh

Configure_Wifi() {
    Print_Info "Configuring Wi-Fi..."

    local remote_script
    remote_script="$(mktemp)"
    cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -e

: "${WIFI_24_SSID:?Missing WIFI_24_SSID}"
: "${WIFI_24_PASSWORD:?Missing WIFI_24_PASSWORD}"
: "${WIFI_5_SSID:?Missing WIFI_5_SSID}"
: "${WIFI_5_PASSWORD:?Missing WIFI_5_PASSWORD}"
: "${WIFI_COUNTRY:?Missing WIFI_COUNTRY}"

configure_lan_ap() {
    radio=$1
    ssid=$2
    password=$3
    configured=0

    uci set "wireless.$radio.disabled=0"
    uci set "wireless.$radio.country=$WIFI_COUNTRY"

    for wifi_section in $(uci show wireless 2>/dev/null | sed -n 's/^wireless\.\([^.=]*\)=wifi-iface$/\1/p'); do
        [ "$(uci -q get "wireless.$wifi_section.device")" = "$radio" ] || continue
        [ "$(uci -q get "wireless.$wifi_section.network")" = 'lan' ] || continue
        uci set "wireless.$wifi_section.ssid=$ssid"
        uci set "wireless.$wifi_section.encryption=sae-mixed"
        uci set "wireless.$wifi_section.key=$password"
        uci set "wireless.$wifi_section.disabled=0"
        configured=1
    done

    [ "$configured" -eq 1 ] || {
        echo "No LAN access point found on $radio" >&2
        return 1
    }
}

configure_lan_ap radio0 "$WIFI_24_SSID" "$WIFI_24_PASSWORD"
iw reg set "$WIFI_COUNTRY" 2>/dev/null || true

# A fixed non-DFS HE80 channel is more reliable during initial boot than
# deriving a primary channel from driver power output. Regulatory power stays
# under driver control.
uci set wireless.radio1.channel='36'
uci set wireless.radio1.htmode='HE80'
uci -q delete wireless.radio1.txpower
configure_lan_ap radio1 "$WIFI_5_SSID" "$WIFI_5_PASSWORD"

uci commit wireless
wifi reload
wifi up
REMOTE

    if ! Router_Ssh \
        "WIFI_24_SSID=$(Shell_Quote "$WIFI_24_SSID") \
         WIFI_24_PASSWORD=$(Shell_Quote "$WIFI_24_PASSWORD") \
         WIFI_5_SSID=$(Shell_Quote "$WIFI_5_SSID") \
         WIFI_5_PASSWORD=$(Shell_Quote "$WIFI_5_PASSWORD") \
         WIFI_COUNTRY=$(Shell_Quote "$WIFI_COUNTRY") \
         sh -s" < "$remote_script"; then
        rm -f "$remote_script"
        Fail_With_Message "Failed to configure Wi-Fi."
    fi

    rm -f "$remote_script"
    Print_Success "Wi-Fi configuration committed and startup requested."
}

Verify_Wifi_Active() {
    Print_Info "Verifying Wi-Fi radios and access points are active..."

    if ! Router_Ssh \
        "EXPECTED_WIFI_24_SSID=$(Shell_Quote "$WIFI_24_SSID") \
         EXPECTED_WIFI_5_SSID=$(Shell_Quote "$WIFI_5_SSID") \
         EXPECTED_IOT_WIFI_SSID=$(Shell_Quote "$IOT_WIFI_SSID") \
         EXPECT_IOT_WIFI=$(Shell_Quote "$INSTALL_HOME_ASSISTANT_IOT") \
         EXPECTED_GUEST_WIFI_SSID=$(Shell_Quote "$GUEST_WIFI_SSID") \
         EXPECT_GUEST_WIFI=$(Shell_Quote "$INSTALL_GUEST_WIFI") \
         sh -s" <<'REMOTE'
set -e
[ "$(uci -q get wireless.radio0.disabled)" = '0' ]
[ "$(uci -q get wireless.radio1.disabled)" = '0' ]
[ "$EXPECT_IOT_WIFI" = '0' ] || [ "$(uci -q get wireless.iot_ap.disabled)" = '0' ]
[ "$EXPECT_GUEST_WIFI" = '0' ] || [ "$(uci -q get wireless.guest_ap.disabled)" = '0' ]
wifi up
[ "$(ubus call network.wireless status | jsonfilter -e '@.radio0.up')" = 'true' ]
[ "$(ubus call network.wireless status | jsonfilter -e '@.radio1.up')" = 'true' ]
iwinfo 2>/dev/null | grep -Fq "ESSID: \"$EXPECTED_WIFI_24_SSID\""
iwinfo 2>/dev/null | grep -Fq "ESSID: \"$EXPECTED_WIFI_5_SSID\""
[ "$EXPECT_IOT_WIFI" = '0' ] || iwinfo 2>/dev/null | grep -Fq "ESSID: \"$EXPECTED_IOT_WIFI_SSID\""
[ "$EXPECT_GUEST_WIFI" = '0' ] || iwinfo 2>/dev/null | grep -Fq "ESSID: \"$EXPECTED_GUEST_WIFI_SSID\""
REMOTE
    then
        Fail_With_Message "Wi-Fi is configured but one or more access points did not start."
    fi

    Print_Success "Both radios and all configured access points are active."
}
