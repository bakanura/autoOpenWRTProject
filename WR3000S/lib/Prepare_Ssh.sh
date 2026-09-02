#!/bin/sh

Prepare_Ssh() {
    SSH_CONTROL_DIR="${XDG_RUNTIME_DIR:-/tmp}/openwrt-router-setup"
    SSH_CONTROL_SOCKET="$SSH_CONTROL_DIR/control"
    SSH_ASKPASS_FILE="$SSH_CONTROL_DIR/askpass"
    SSH_PASSWORD_FILE="$SSH_CONTROL_DIR/password"

    mkdir -p "$SSH_CONTROL_DIR"

    chmod 700 "$SSH_CONTROL_DIR"

    rm -f "$SSH_CONTROL_SOCKET"
    rm -f "$SSH_ASKPASS_FILE"
    rm -f "$SSH_PASSWORD_FILE"


    # --------------------------------------------------------
    # Store current password.
    #
    # An empty password is represented by an empty line.
    # --------------------------------------------------------

    printf '%s\n' "$CURRENT_ROOT_PASSWORD" \
        > "$SSH_PASSWORD_FILE"

    chmod 600 "$SSH_PASSWORD_FILE"


    # --------------------------------------------------------
    # Askpass helper.
    #
    # It reads the protected password file rather than relying
    # on environment propagation into ssh_askpass.
    # --------------------------------------------------------

    cat > "$SSH_ASKPASS_FILE" <<EOF
#!/bin/sh
cat $(Shell_Quote "$SSH_PASSWORD_FILE")
EOF

    chmod 700 "$SSH_ASKPASS_FILE"


    # --------------------------------------------------------
    # OpenSSH environment.
    # --------------------------------------------------------

    export SSH_ASKPASS="$SSH_ASKPASS_FILE"
    export SSH_ASKPASS_REQUIRE=force
    export DISPLAY="${DISPLAY:-:0}"


    SSH_OPTS=(
        -o ConnectTimeout=10
        -o ConnectionAttempts=1
        -o ServerAliveInterval=15
        -o ServerAliveCountMax=3
        -o StrictHostKeyChecking=accept-new
        -o PubkeyAuthentication=no
        -o PreferredAuthentications=password,keyboard-interactive
        -o ControlMaster=auto
        -o ControlPersist=300
        -o ControlPath="$SSH_CONTROL_SOCKET"
    )
}
