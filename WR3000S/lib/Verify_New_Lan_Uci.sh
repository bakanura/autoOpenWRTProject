#!/bin/sh

Verify_New_Lan_Uci() {
    local new_cidr="${ROUTER_NEW}/24"

    Router_Ssh "
        uci -q get network.lan.ipaddr |
            tr ' ' '\n' |
            grep -Fxq $(Shell_Quote "$new_cidr")
    "
}
