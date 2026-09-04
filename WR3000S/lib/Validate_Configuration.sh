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

    (( ${#WIFI_24_PASSWORD} >= 8 && ${#WIFI_24_PASSWORD} <= 63 )) ||
        Fail_With_Message "2.4 GHz Wi-Fi password must be 8-63 characters."

    [[ -n "$WIFI_5_PASSWORD" ]] ||
        Fail_With_Message \
            "5 GHz Wi-Fi password cannot be empty."

    (( ${#WIFI_5_PASSWORD} >= 8 && ${#WIFI_5_PASSWORD} <= 63 )) ||
        Fail_With_Message "5 GHz Wi-Fi password must be 8-63 characters."

    (( ${#WIFI_24_SSID} >= 1 && ${#WIFI_24_SSID} <= 32 )) ||
        Fail_With_Message "2.4 GHz SSID must be 1-32 characters."
    (( ${#WIFI_5_SSID} >= 1 && ${#WIFI_5_SSID} <= 32 )) ||
        Fail_With_Message "5 GHz SSID must be 1-32 characters."

    [[ "$INSTALL_HOME_ASSISTANT_IOT" == "0" || "$INSTALL_HOME_ASSISTANT_IOT" == "1" ]] ||
        Fail_With_Message "INSTALL_HOME_ASSISTANT_IOT must be 0 or 1."

    if (( INSTALL_HOME_ASSISTANT_IOT == 1 )); then
        Validate_Ip_Address "$HOME_ASSISTANT_IP" ||
            Fail_With_Message "Invalid Home Assistant IP: $HOME_ASSISTANT_IP"
        [[ -n "$IOT_WIFI_PASSWORD" ]] ||
            Fail_With_Message "IoT Wi-Fi password cannot be empty."
        (( ${#IOT_WIFI_PASSWORD} >= 8 && ${#IOT_WIFI_PASSWORD} <= 63 )) ||
            Fail_With_Message "IoT Wi-Fi password must be 8-63 characters."
        (( ${#IOT_WIFI_SSID} >= 1 && ${#IOT_WIFI_SSID} <= 32 )) ||
            Fail_With_Message "IoT SSID must be 1-32 characters."
    fi

    [[ "$INSTALL_GUEST_WIFI" == "0" || "$INSTALL_GUEST_WIFI" == "1" ]] ||
        Fail_With_Message "INSTALL_GUEST_WIFI must be 0 or 1."
    if (( INSTALL_GUEST_WIFI == 1 )); then
        (( ${#GUEST_WIFI_PASSWORD} >= 8 && ${#GUEST_WIFI_PASSWORD} <= 63 )) ||
            Fail_With_Message "Guest Wi-Fi password must be 8-63 characters."
        (( ${#GUEST_WIFI_SSID} >= 1 && ${#GUEST_WIFI_SSID} <= 32 )) ||
            Fail_With_Message "Guest SSID must be 1-32 characters."
    fi

    [[ "$INSTALL_ADGUARD_HOME" == "0" || "$INSTALL_ADGUARD_HOME" == "1" ]] ||
        Fail_With_Message "INSTALL_ADGUARD_HOME must be 0 or 1."
    if (( INSTALL_ADGUARD_HOME == 1 )); then
        [[ "$ADGUARD_ADMIN_USER" =~ ^[A-Za-z0-9_.-]+$ ]] || Fail_With_Message "Invalid AdGuard administrator name."
        [[ ${#ADGUARD_ADMIN_PASSWORD} -ge 8 ]] || Fail_With_Message "AdGuard administrator password must be at least 8 characters."
    fi
    [[ "$ENFORCE_ADGUARD_DNS" == "0" || "$ENFORCE_ADGUARD_DNS" == "1" ]] ||
        Fail_With_Message "ENFORCE_ADGUARD_DNS must be 0 or 1."

    [[ "$ENABLE_IGMP_SNOOPING" == "0" || "$ENABLE_IGMP_SNOOPING" == "1" ]] ||
        Fail_With_Message "ENABLE_IGMP_SNOOPING must be 0 or 1."

    [[ "$INSTALL_SSH_AUTHORIZED_KEY" == "0" || "$INSTALL_SSH_AUTHORIZED_KEY" == "1" ]] ||
        Fail_With_Message "INSTALL_SSH_AUTHORIZED_KEY must be 0 or 1."

    [[ "$SSH_KEY_ONLY" == "0" || "$SSH_KEY_ONLY" == "1" ]] ||
        Fail_With_Message "SSH_KEY_ONLY must be 0 or 1."

    if (( INSTALL_SSH_AUTHORIZED_KEY == 1 )) && [[ -z "$AUTHORIZED_SSH_KEY" ]]; then
        Fail_With_Message "SSH key installation requires AUTHORIZED_SSH_KEY."
    fi

    if (( SSH_KEY_ONLY == 1 )) && (( INSTALL_SSH_AUTHORIZED_KEY != 1 )); then
        Fail_With_Message "SSH_KEY_ONLY=1 requires SSH key installation."
    fi

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
        [[ "$ALLOW_TAILSCALE_ROUTER_MANAGEMENT" == "0" || "$ALLOW_TAILSCALE_ROUTER_MANAGEMENT" == "1" ]] ||
            Fail_With_Message "ALLOW_TAILSCALE_ROUTER_MANAGEMENT must be 0 or 1."
        [[ "$ENABLE_TAILSCALE_REMOTE_ROUTERS" == "0" || "$ENABLE_TAILSCALE_REMOTE_ROUTERS" == "1" ]] ||
            Fail_With_Message "ENABLE_TAILSCALE_REMOTE_ROUTERS must be 0 or 1."
    fi

    if (( INSTALL_AURORA == 0 )) &&
       [[ -n "$CUSTOM_SETUP_URL" ]]; then

        [[ "$CUSTOM_SETUP_URL" =~ ^https:// ]] ||
            Fail_With_Message \
                "Custom setup URL must use HTTPS."
        [[ "$CUSTOM_SETUP_SHA256" =~ ^[A-Fa-f0-9]{64}$ ]] ||
            Fail_With_Message "CUSTOM_SETUP_SHA256 must contain 64 hexadecimal characters."
    fi
}
