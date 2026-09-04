#!/bin/sh

Add_IoT_Whitelist_Rule()
{
    if [ -z "${DEVICE_IP-}" ] || [ -z "${DEST_ZONE-}" ]; then
        echo "Invalid IoT whitelist: DEVICE_IP and DEST_ZONE required"
        return 1
    fi

    case "$DEST_ZONE" in
        wan|lan) ;;
        *)
            echo "Invalid IoT whitelist destination"
            return 1
            ;;
    esac

    DEVICE_IP="$1"
    DEST_ZONE="$2"
    DEST_IP="${3-}"

    [ -z "$DEVICE_IP" ] && return 1
    [ -z "$DEST_ZONE" ] && return 1

    uci add firewall rule
    uci set firewall.@rule[-1].name="Allow-IoT-${DEVICE_IP}-${DEST_ZONE}"
    uci set firewall.@rule[-1].src="iot"
    uci set firewall.@rule[-1].src_ip="$DEVICE_IP"
    uci set firewall.@rule[-1].dest="$DEST_ZONE"
    uci set firewall.@rule[-1].target="ACCEPT"

    [ -n "$DEST_IP" ] &&
        uci set firewall.@rule[-1].dest_ip="$DEST_IP"
}
