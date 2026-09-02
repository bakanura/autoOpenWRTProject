#!/bin/sh

Open_Ssh_Master() {
    local ip="$1"

    CURRENT_ROUTER_IP="$ip"

    ssh \
        "${SSH_OPTS[@]}" \
        -o ControlMaster=yes \
        -o ControlPersist=300 \
        "root@$ip" \
        'printf "SSH connection established\n"' \
        >/dev/null
}
