#!/bin/sh

Can_Ssh() {
    local ip="$1"

    ssh \
        "${SSH_OPTS[@]}" \
        -o ControlMaster=no \
        -o ControlPath=none \
        "root@$ip" \
        'true' \
        >/dev/null 2>&1
}
