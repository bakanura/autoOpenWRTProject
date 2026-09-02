#!/bin/sh

Validate_Ip_Address() {
    local ip="$1"
    local IFS=.
    local octet
    local -a parts

    read -r -a parts <<< "$ip"

    [[ "${#parts[@]}" -eq 4 ]] || return 1

    for octet in "${parts[@]}"; do
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done
}
