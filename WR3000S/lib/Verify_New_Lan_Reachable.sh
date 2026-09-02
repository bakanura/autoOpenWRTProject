#!/bin/sh

Verify_New_Lan_Reachable() {
    local attempts=0

    Print_Info \
        "Waiting for $ROUTER_NEW..."

    while (( attempts < 30 )); do

        if ping \
            -c 1 \
            -W 1 \
            "$ROUTER_NEW" \
            >/dev/null 2>&1; then

            Print_Success \
                "$ROUTER_NEW is reachable."

            return 0
        fi

        attempts=$((attempts + 1))

        sleep 1
    done

    return 1
}
