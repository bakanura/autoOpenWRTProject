#!/bin/sh

Wait_For_New_Ssh() {
    local attempts=0

    Close_Ssh_Master

    Print_Info \
        "Waiting for the router to return on $ROUTER_NEW..."


    while (( attempts < 30 )); do

        if Can_Ssh "$ROUTER_NEW"; then

            Open_Ssh_Master "$ROUTER_NEW"

            Print_Success \
                "Reconnected to the router at $ROUTER_NEW."

            return 0
        fi

        attempts=$((attempts + 1))

        sleep 1
    done


    Fail_With_Message \
        "The router did not become reachable on $ROUTER_NEW after the LAN change."
}
