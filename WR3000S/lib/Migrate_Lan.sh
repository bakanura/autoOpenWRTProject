#!/bin/sh

Migrate_Lan() {
    local new_cidr="${ROUTER_NEW}/24"
    local old_cidr="${ROUTER_OLD}/24"


    # --------------------------------------------------------
    # RERUN / INTERMEDIATE STATE
    #
    # We connected using the NEW address.
    #
    # Do NOT blindly skip.
    #
    # The previous installer could have produced:
    #
    #   UCI:     192.168.1.1/24 192.168.8.1
    #   br-lan:  192.168.1.1/24 192.168.8.1/32
    #
    # Repair that automatically.
    # --------------------------------------------------------

    if (( FIRST_IP_FAILED == 1 )); then

        Print_Info \
            "Connected through $ROUTER_NEW; checking LAN configuration..."

        if Verify_New_Lan_On_Router &&
           ! Verify_Old_Lan_Uci; then

            Print_Success \
                "LAN configuration is already correct."

            CURRENT_ROUTER_IP="$ROUTER_NEW"

            return 0
        fi


        Print_Warning \
            "LAN configuration needs repair."
    fi


    # --------------------------------------------------------
    # Stage/repair exact /24.
    #
    # Remove:
    #   192.168.8.1
    #   192.168.8.1/32
    #   192.168.8.1/24
    #
    # Then add:
    #   192.168.8.1/24
    # --------------------------------------------------------

    Print_Info \
        "Repairing LAN address configuration..."


    Router_Ssh "
        set -e

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


    # --------------------------------------------------------
    # FIRST RUN:
    #
    # We are connected via old address.
    # Verify new address before removing old.
    # --------------------------------------------------------

    if (( FIRST_IP_FAILED == 0 )); then

        Verify_New_Lan_Uci ||
            Fail_With_Message \
                "Failed to stage $new_cidr."

        Print_Success \
            "Staged $new_cidr while preserving $old_cidr."


        if ! Verify_New_Lan_Reachable; then

            Fail_With_Message \
                "Could not reach $ROUTER_NEW. The old LAN address was preserved."
        fi

        Print_Success \
            "$ROUTER_NEW is reachable."
    fi


    # --------------------------------------------------------
    # If we got here:
    #
    #   new address is reachable
    #   OR we are already connected through new address.
    #
    # Now remove old address.
    # --------------------------------------------------------

    if Verify_Old_Lan_Uci; then

        Print_Info \
            "Removing old LAN address $old_cidr..."

        Router_Ssh "
            set -e

            uci del_list network.lan.ipaddr=$(Shell_Quote "$old_cidr") \
                2>/dev/null || true

            uci del_list network.lan.ipaddr=$(Shell_Quote "$ROUTER_OLD") \
                2>/dev/null || true

            uci commit network

            nohup sh -c '
                sleep 1
                /etc/init.d/network reload
            ' >/dev/null 2>&1 </dev/null &
        "

        Print_Success \
            "Old LAN address removal scheduled."

        Wait_For_New_Ssh

    else

        Print_Info \
            "Old LAN address is already absent."
    fi


    FIRST_IP_FAILED=1

    Print_Success \
        "LAN migration/repair completed."
}
