#!/bin/sh

Verify_Final_Lan() {
    local new_cidr="${ROUTER_NEW}/24"
    local old_cidr="${ROUTER_OLD}/24"


    Print_Info \
        "Verifying final LAN configuration..."


    # --------------------------------------------------------
    # Verify actual live interface.
    # --------------------------------------------------------

    Router_Ssh "
        set -e

        ip -4 addr show dev br-lan |
            grep -Fq 'inet ${new_cidr} '
    " || Fail_With_Message \
        "Final LAN live-interface verification failed."


    # --------------------------------------------------------
    # Verify UCI has exact /24.
    # --------------------------------------------------------

    Verify_New_Lan_Uci ||
        Fail_With_Message \
            "Final LAN UCI verification failed."


    # --------------------------------------------------------
    # Old address must not remain after migration.
    # --------------------------------------------------------

    if Verify_Old_Lan_Uci; then

        Fail_With_Message \
            "Old LAN address $old_cidr is still configured."
    fi


    Print_Success \
        "Final LAN configuration verified: $new_cidr."
}
