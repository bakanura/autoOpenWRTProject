#!/bin/sh

Router_Ssh() {
    local cmd="$*"

    ssh \
        "${SSH_OPTS[@]}" \
        "root@$CURRENT_ROUTER_IP" \
        "$cmd"
}
