#!/bin/sh

Configure_IoT_Firewall()
{
    Print_Info "Configuring IoT firewall"

    uci add firewall zone
    uci set firewall.@zone[-1].name='iot'
    uci set firewall.@zone[-1].network='iot'
    uci set firewall.@zone[-1].input='REJECT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci set firewall.@zone[-1].forward='REJECT'

    uci -q delete firewall.@zone[-1].masq

    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='iot'

    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-IoT-DNS-DHCP'
    uci set firewall.@rule[-1].src='iot'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].dest_port='53 67 68'
    uci set firewall.@rule[-1].target='ACCEPT'

    uci commit firewall
}
