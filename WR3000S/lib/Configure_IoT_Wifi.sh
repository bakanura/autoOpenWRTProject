#!/bin/sh

Configure_IoT_Wifi() {
    Print_Info "Configuring IoT WiFi"

    # Remove existing bakasifu-IoT AP if reinstalling
    for section in $(uci show wireless | grep "ssid='bakasifu-IoT'" | cut -d'.' -f2 | cut -d'=' -f1); do
        uci delete wireless.$section
    done

    uci add wireless wifi-iface
    uci set wireless.@wifi-iface[-1].device='radio0'
    uci set wireless.@wifi-iface[-1].mode='ap'
    uci set wireless.@wifi-iface[-1].disabled='0'
    uci set wireless.@wifi-iface[-1].network='iot'
    uci set wireless.@wifi-iface[-1].ssid='bakasifu-IoT'
    uci set wireless.@wifi-iface[-1].encryption='psk2'
    uci set wireless.@wifi-iface[-1].key="${IOT_WIFI_PASSWORD}"

    uci commit wireless
}
