#!/bin/sh

Configure_IoT()
{
    Print_Info "Configuring IoT network"

    uci set network.iot='interface'
    uci set network.iot.proto='static'
    uci set network.iot.ipaddr='192.168.9.1'
    uci set network.iot.netmask='255.255.255.0'

    uci set dhcp.iot='dhcp'
    uci set dhcp.iot.interface='iot'
    uci set dhcp.iot.start='100'
    uci set dhcp.iot.limit='150'
    uci set dhcp.iot.leasetime='12h'

    uci commit network
    uci commit dhcp
}
