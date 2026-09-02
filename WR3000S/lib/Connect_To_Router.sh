#!/bin/sh

Connect_To_Router() {
    # --------------------------------------------------------
    # Try FINAL address first.
    #
    # This is what makes reruns fast.
    # --------------------------------------------------------

    Print_Info \
        "Connecting to $ROUTER_NEW..."

    if Open_Ssh_Master "$ROUTER_NEW"; then

        FIRST_IP_FAILED=1

        Print_Success \
            "Connected to the router at $ROUTER_NEW."

        return 0
    fi


    Print_Warning \
        "Could not connect to $ROUTER_NEW."


    # --------------------------------------------------------
    # First-run fallback.
    # --------------------------------------------------------

    Print_Info \
        "Trying $ROUTER_OLD..."

    if Open_Ssh_Master "$ROUTER_OLD"; then

        FIRST_IP_FAILED=0

        Print_Success \
            "Connected to the router at $ROUTER_OLD."

        return 0
    fi


    Fail_With_Message \
        "Could not connect to the router at either $ROUTER_NEW or $ROUTER_OLD."
}
