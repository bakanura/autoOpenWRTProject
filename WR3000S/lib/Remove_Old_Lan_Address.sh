#!/bin/sh

Remove_Old_Lan_Address() {
    local old_cidr="${ROUTER_OLD}/24"

    Print_Info \
        "Removing old LAN address $old_cidr..."


    Router_Ssh "
        set -e

        uci del_list network.lan.ipaddr=$(Shell_Quote "$old_cidr") \
            2>/dev/null || true

        uci del_list network.lan.ipaddr=$(Shell_Quote "$ROUTER_OLD") \
            2>/dev/null || true

        uci commit network

        # Never synchronously reload while connected through
        # the address being removed.

        nohup sh -c '
            sleep 1
            /etc/init.d/network reload
        ' >/dev/null 2>&1 </dev/null &
    "


    Print_Success \
        "Old LAN address removal scheduled."
}
