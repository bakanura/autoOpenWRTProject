#!/bin/sh

Validate_Configuration() {
    Validate_Ip_Address "$ROUTER_OLD" ||
        Fail_With_Message \
            "Invalid old router IP: $ROUTER_OLD"

    Validate_Ip_Address "$ROUTER_NEW" ||
        Fail_With_Message \
            "Invalid new router IP: $ROUTER_NEW"

    [[ "$ROUTER_OLD" != "$ROUTER_NEW" ]] ||
        Fail_With_Message \
            "Old and new router IP addresses cannot be identical."

    [[ -n "$ROOT_PASSWORD" ]] ||
        Fail_With_Message \
            "New router root password cannot be empty."

    [[ -n "$WIFI_24_PASSWORD" ]] ||
        Fail_With_Message \
            "2.4 GHz Wi-Fi password cannot be empty."

    [[ -n "$WIFI_5_PASSWORD" ]] ||
        Fail_With_Message \
            "5 GHz Wi-Fi password cannot be empty."

    [[ "$INSTALL_AURORA" == "0" ||
       "$INSTALL_AURORA" == "1" ]] ||
        Fail_With_Message \
            "INSTALL_AURORA must be 0 or 1."

    [[ "$INSTALL_TAILSCALE" == "0" ||
       "$INSTALL_TAILSCALE" == "1" ]] ||
        Fail_With_Message \
            "INSTALL_TAILSCALE must be 0 or 1."

    if (( INSTALL_TAILSCALE == 1 )); then

        [[ "$INSTALL_TAILSCALE_ROUTES" == "0" ||
           "$INSTALL_TAILSCALE_ROUTES" == "1" ]] ||
            Fail_With_Message \
                "INSTALL_TAILSCALE_ROUTES must be 0 or 1."
    fi

    if (( INSTALL_AURORA == 0 )) &&
       [[ -n "$CUSTOM_SETUP_URL" ]]; then

        [[ "$CUSTOM_SETUP_URL" =~ ^https?:// ]] ||
            Fail_With_Message \
                "Custom setup URL must start with http:// or https://."
    fi
}
