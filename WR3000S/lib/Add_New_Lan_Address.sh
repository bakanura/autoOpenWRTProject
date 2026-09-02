#!/bin/sh

Add_New_Lan_Address() {
    local new_cidr="${ROUTER_NEW}/24"

    Print_Info \
        "Adding $new_cidr while keeping $ROUTER_OLD/24..."


    Router_Ssh "
        set -e

        # Remove every known bad/canonical representation
        # before adding the correct CIDR.

        uci del_list network.lan.ipaddr=$(Shell_Quote "$ROUTER_NEW") \
            2>/dev/null || true

        uci del_list network.lan.ipaddr=$(Shell_Quote "$ROUTER_NEW/32") \
            2>/dev/null || true

        uci del_list network.lan.ipaddr=$(Shell_Quote "$new_cidr") \
            2>/dev/null || true

        uci add_list network.lan.ipaddr=$(Shell_Quote "$new_cidr")

        uci commit network

        ubus call network reload
    "
}
