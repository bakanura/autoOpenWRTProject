#!/bin/sh

Cleanup() {
    if [[ -n "${CURRENT_ROUTER_IP:-}" ]] &&
       [[ -n "${SSH_CONTROL_SOCKET:-}" ]]; then

        ssh \
            "${SSH_OPTS[@]}" \
            -O exit \
            "root@$CURRENT_ROUTER_IP" \
            >/dev/null 2>&1 || true
    fi

    if [[ -n "${SSH_ASKPASS_FILE:-}" ]]; then
        rm -f "$SSH_ASKPASS_FILE" 2>/dev/null || true
    fi

    if [[ -n "${SSH_PASSWORD_FILE:-}" ]]; then
        rm -f "$SSH_PASSWORD_FILE" 2>/dev/null || true
    fi

    if [[ -n "${SSH_CONTROL_DIR:-}" ]]; then
        rmdir "$SSH_CONTROL_DIR" 2>/dev/null || true
    fi

    unset CURRENT_ROOT_PASSWORD
    unset ROOT_PASSWORD
}
