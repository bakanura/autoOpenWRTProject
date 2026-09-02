#!/bin/sh

Wait_For_Wan() {
    Print_Info \
        "Checking WAN connectivity..."

    local attempt=0
    local max_attempts=60

    while (( attempt < max_attempts )); do
        attempt=$((attempt + 1))

        local wan_ip=""
        wan_ip="$(Get_Wan_Ip)"

        if [[ -n "$wan_ip" ]] && \
           Has_Default_Route && \
           Test_Router_Internet; then

            Print_Success \
                "WAN connected: $wan_ip."
            return 0
        fi

        Print_Warning \
            "WAN not ready ($attempt/$max_attempts)."

        Router_Ssh '
            echo "=== DEFAULT ROUTE ==="
            ip route show default || true

            echo "=== WAN STATUS ==="
            ubus call network.interface.wan status 2>/dev/null || true

            echo "=== DNS ==="
            cat /tmp/resolv.conf.d/resolv.conf.auto 2>/dev/null || true
        ' || true

        sleep 5
    done

    Fail_With_Message \
        "WAN did not become available after waiting."
}
