#!/bin/sh

Configure_Guest_Wifi() {
    Print_Info "Configuring Guest WiFi"

    # Remove existing bakasifu-Guest AP if reinstalling
    for section in $(uci show wireless | grep "ssid='bakasifu-Guest'" | cut -d'.' -f2 | cut -d'=' -f1); do
        uci delete wireless.$section
    done

    uci add wireless wifi-iface
    uci set wireless.@wifi-iface[-1].device='radio0'
    uci set wireless.@wifi-iface[-1].mode='ap'
    uci set wireless.@wifi-iface[-1].disabled='0'
    uci set wireless.@wifi-iface[-1].network='guest'
    uci set wireless.@wifi-iface[-1].ssid='bakasifu-Guest'
    uci set wireless.@wifi-iface[-1].encryption='psk2'
    uci set wireless.@wifi-iface[-1].key="${GUEST_WIFI_PASSWORD}"

    uci commit wireless
}
