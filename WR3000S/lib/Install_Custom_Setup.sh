#!/bin/sh

Install_Custom_Setup() {
    if [[ -z "$CUSTOM_SETUP_URL" ]]; then

        Print_Info \
            "No custom LuCI/theme setup selected."

        return 0
    fi


    [[ "$CUSTOM_SETUP_URL" =~ ^https:// ]] ||
        Fail_With_Message \
            "Custom setup URL must use HTTPS."


    printf '\n'


    Print_Warning \
        "The following URL will be downloaded and executed as root on the router:"


    printf '%s\n' \
        "$CUSTOM_SETUP_URL"


    printf '\n'


    local answer


    read -r \
        -p "Continue with this custom setup script? [y/N]: " \
        answer


    case "$answer" in
        y|Y|yes|YES)
            ;;
        *)
            Print_Info \
                "Custom setup script cancelled."

            return 0
            ;;
    esac


    Print_Info \
        "Downloading and executing custom setup script..."


    local remote_script

    remote_script="$(mktemp)"


    cat > "$remote_script" <<EOF
#!/bin/sh
set -e

URL=$(Shell_Quote "$CUSTOM_SETUP_URL")
EXPECTED_SHA256=$(Shell_Quote "$CUSTOM_SETUP_SHA256")

tmp=\$(mktemp)


cleanup() {
    rm -f "\$tmp"
}


trap cleanup EXIT INT TERM


wget \
    -O "\$tmp" \
    "\$URL"

actual_sha256=\$(sha256sum "\$tmp" | awk '{print \$1}')
[ "\$actual_sha256" = "\$EXPECTED_SHA256" ] || {
    echo "Custom setup SHA-256 mismatch" >&2
    exit 1
}


chmod 700 "\$tmp"


sh "\$tmp"
EOF


    if ! Router_Ssh 'sh -s' < "$remote_script"; then

        rm -f "$remote_script"

        Fail_With_Message \
            "Custom setup script failed."
    fi


    rm -f "$remote_script"


    Print_Success \
        "Custom setup script completed."
}
