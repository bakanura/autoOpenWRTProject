#!/bin/sh

Router_Ssh() {
    ssh \
        "${SSH_OPTS[@]}" \
        "root@$CURRENT_ROUTER_IP" \
        "$@"
}
