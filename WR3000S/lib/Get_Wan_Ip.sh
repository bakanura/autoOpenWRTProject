#!/bin/sh

Get_Wan_Ip() {
    Router_Ssh '
        ubus call network.interface.wan status 2>/dev/null |
            jsonfilter \
                -e "@[\"ipv4-address\"][0].address" \
            2>/dev/null ||
            true
    '
}
