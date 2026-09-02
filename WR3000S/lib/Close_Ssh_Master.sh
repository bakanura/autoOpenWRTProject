#!/bin/sh

Close_Ssh_Master() {
    if [[ -n "${CURRENT_ROUTER_IP:-}" ]]; then

        ssh \
            "${SSH_OPTS[@]}" \
            -O exit \
            "root@$CURRENT_ROUTER_IP" \
            >/dev/null 2>&1 || true
    fi
}
