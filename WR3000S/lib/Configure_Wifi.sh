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

configure_radio() {
    radio="$1"
    ssid="$2"
    password="$3"

    uci set "wireless.$radio.disabled=0"
    uci set "wireless.$radio.country=$WIFI_COUNTRY"

    for iface in $(uci show wireless 2>/dev/null |
        sed -n 's/^wireless\.\([^=]*\)=wifi-iface$/\1/p'); do

        device="$(uci -q get "wireless.$iface.device" 2>/dev/null || true)"

        [ "$device" = "$radio" ] || continue

        uci set "wireless.$iface.ssid=$ssid"
        uci set "wireless.$iface.encryption=sae-mixed"
        uci set "wireless.$iface.key=$password"
    done
}

configure_radio radio0 "$WIFI_24_SSID" "$WIFI_24_PASSWORD"
iw reg set "$WIFI_COUNTRY" 2>/dev/null || true

    wifi_5_channel=""
    wifi_5_power="0"

    while read -r channel power flags; do
        [ -n "$channel" ] || continue
        [ -n "$power" ] || continue

        case "$flags" in
            *radar*|*NO-IR*|*disabled*)
                continue
                ;;
        esac

        case "$channel" in
            36|40|44|48|52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|144|149|153|157|161|165)
                ;;
            *)
                continue
                ;;
        esac

        if awk "BEGIN { exit !($power > $wifi_5_power) }"; then
            wifi_5_channel="$channel"
            wifi_5_power="$power"
        fi
    done < <(
        iw phy phy1 info 2>/dev/null |
        awk '
            /MHz \[[0-9]+\]/ {
                channel=""
                power=""
                flags=$0

                if (match($0, /\[[0-9]+\]/))
                    channel=substr($0, RSTART + 1, RLENGTH - 2)

                if (match($0, /\(([0-9]+\.[0-9]+) dBm\)/))
                    power=substr($0, RSTART + 1, RLENGTH - 6)

                if (channel != "" && power != "")
                    printf "%s %s %s\n", channel, power, flags
            }
        '
    )

    if [ -z "$wifi_5_channel" ]; then
        wifi_5_channel="36"
        uci -q delete wireless.radio1.txpower
    else
        uci set wireless.radio1.txpower="$wifi_5_power"
    fi

    uci set wireless.radio1.channel="$wifi_5_channel"
    uci set wireless.radio1.htmode="HE80"

    printf 'Selected 5 GHz channel: %s (maximum legal power: %s dBm)\n'         "$wifi_5_channel" "$wifi_5_power"

    configure_radio radio1 "$WIFI_5_SSID" "$WIFI_5_PASSWORD"

uci commit wireless
wifi reload
REMOTE

    if ! Router_Ssh \
        "WIFI_24_SSID=$(Shell_Quote "$WIFI_24_SSID") \
         WIFI_24_PASSWORD=$(Shell_Quote "$WIFI_24_PASSWORD") \
         WIFI_5_SSID=$(Shell_Quote "$WIFI_5_SSID") \
         WIFI_5_PASSWORD=$(Shell_Quote "$WIFI_5_PASSWORD") \
         sh -s" < "$remote_script"; then

        rm -f "$remote_script"
        Print_Error "Failed to configure Wi-Fi."
        return 1
    fi

    rm -f "$remote_script"

    Print_Info "Wi-Fi configured."
}
