#!/bin/sh

Apk_Update() {
    local attempt


    for attempt in 1 2 3 4 5; do

        Print_Info \
            "Updating OpenWrt package indexes (attempt $attempt/5)..."


        if Router_Ssh '
            # Wait for any existing apk process
            for i in $(seq 1 30); do
                if ! pgrep -x apk >/dev/null 2>&1; then
                    break
                fi
                echo "Waiting for existing apk process..."
                sleep 2
            done

            # Remove stale apk lock if no apk process remains
            if ! pgrep -x apk >/dev/null 2>&1; then
                rm -f /var/lib/apk/*.lock 2>/dev/null || true
            fi

            apk update
        '; then

            Print_Success \
                "OpenWrt package indexes updated."

            return 0
        fi


        if (( attempt < 5 )); then

            Print_Warning \
                "apk update failed; retrying in 5 seconds..."

            sleep 5
        fi
    done


    Print_Error \
        "apk update failed after 5 attempts."


    Print_Info \
        "Running router network diagnostics..."


    Router_Ssh '
        printf "\n=== DEFAULT ROUTE ===\n"
        ip route show default ||
            true

        printf "\n=== WAN STATUS ===\n"
        ubus call network.interface.wan status 2>/dev/null ||
            true

        printf "\n=== DNS ===\n"
        cat \
            /tmp/resolv.conf.d/resolv.conf.auto \
            2>/dev/null ||
            true

        printf "\n=== HTTPS CONNECTIVITY ===\n"
        wget \
            -S \
            -O /dev/null \
            https://downloads.openwrt.org/ \
            2>&1 ||
            true
    ' || true


    Fail_With_Message \
        "OpenWrt package indexes could not be updated."
}
