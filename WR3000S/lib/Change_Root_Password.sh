#!/bin/sh

Change_Root_Password() {
    Print_Info \
        "Changing root password..."


    local remote_script

    remote_script="$(mktemp)"


    cat > "$remote_script" <<EOF
#!/bin/sh
set -e

ROOT_PASSWORD=$(Shell_Quote "$ROOT_PASSWORD")

printf '%s\n%s\n' \
    "\$ROOT_PASSWORD" \
    "\$ROOT_PASSWORD" |
    passwd root
EOF


    if ! Router_Ssh 'sh -s' < "$remote_script"; then

        rm -f "$remote_script"

        Fail_With_Message \
            "Failed to change the router root password."
    fi


    rm -f "$remote_script"


    # --------------------------------------------------------
    # The existing ControlMaster remains authenticated.
    #
    # Do NOT destroy/recreate its socket here.
    #
    # Just update the askpass password file.
    # --------------------------------------------------------

    CURRENT_ROOT_PASSWORD="$ROOT_PASSWORD"

    export CURRENT_ROOT_PASSWORD


    printf '%s\n' "$CURRENT_ROOT_PASSWORD" \
        > "$SSH_PASSWORD_FILE"

    chmod 600 "$SSH_PASSWORD_FILE"


    Print_Success \
        "Root password changed."
}
