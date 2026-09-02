#!/bin/sh

Verify_New_Lan_On_Router() {
    local new_cidr="${ROUTER_NEW}/24"

    Router_Ssh "
        ip -4 addr show dev br-lan |
            grep -Fq 'inet ${new_cidr} '
    "
}
