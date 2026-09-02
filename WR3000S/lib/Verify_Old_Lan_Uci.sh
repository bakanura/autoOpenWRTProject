#!/bin/sh

Verify_Old_Lan_Uci() {
    local old_cidr="${ROUTER_OLD}/24"

    Router_Ssh "
        uci -q get network.lan.ipaddr |
            tr ' ' '\n' |
            grep -Fxq $(Shell_Quote "$old_cidr")
    "
}
