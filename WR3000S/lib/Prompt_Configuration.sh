#!/bin/sh

Prompt_Configuration() {

    echo "[INFO] Preset configuration:"
    for v in INSTALL_HOME_ASSISTANT_IOT INSTALL_GUEST_WIFI INSTALL_ADGUARD_HOME INSTALL_SSH_AUTHORIZED_KEY SSH_KEY_ONLY INSTALL_TAILSCALE INSTALL_TAILSCALE_ROUTES INSTALL_TAILSCALE_LAN_ACCESS ALLOW_TAILSCALE_ROUTER_MANAGEMENT INSTALL_AURORA; do
        eval "val=\${$v:-}"
        [ -n "$val" ] && echo "[INFO] $v=$val"
    done

    # Respect exported environment variables
    WIFI_COUNTRY="${WIFI_COUNTRY:-DE}"

    printf '\n'
    printf '%s\n' '=== WR3000S FULL SETUP ==='
    printf '\n'

    if [[ -z "${WIFI_COUNTRY-}" ]]; then
        read -r -p "Country where the router will be operated (ISO 3166-1 code, e.g. DE): " WIFI_COUNTRY
        WIFI_COUNTRY="${WIFI_COUNTRY^^}"
        [[ "$WIFI_COUNTRY" =~ ^[A-Z]{2}$ ]] ||
            Fail_With_Message "Wi-Fi country must be a 2-letter ISO country code, e.g. DE."
    else
        WIFI_COUNTRY="${WIFI_COUNTRY^^}"
        [[ "$WIFI_COUNTRY" =~ ^[A-Z]{2}$ ]] ||
            Fail_With_Message "Wi-Fi country must be a 2-letter ISO country code."
    fi


    # --------------------------------------------------------
    # CURRENT ROOT PASSWORD
    #
    # Empty is deliberately allowed.
    # Press ENTER on a fresh router.
    # --------------------------------------------------------

    if [[ -z "$CURRENT_ROOT_PASSWORD" ]]; then

        read -r -s \
            -p "Current router root password: " \
            CURRENT_ROOT_PASSWORD

        printf '\n'
    fi


    # --------------------------------------------------------
    # NEW ROOT PASSWORD
    # --------------------------------------------------------

    if [[ -z "$ROOT_PASSWORD" ]]; then

        read -r -s \
            -p "New router root password: " \
            ROOT_PASSWORD

        printf '\n'

        [[ -n "$ROOT_PASSWORD" ]] ||
            Fail_With_Message \
                "New router root password cannot be empty."

        local ROOT_PASSWORD_CONFIRM

        read -r -s \
            -p "Confirm new router root password: " \
            ROOT_PASSWORD_CONFIRM

        printf '\n'

        [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]] ||
            Fail_With_Message \
                "New root passwords do not match."

        unset ROOT_PASSWORD_CONFIRM
    fi


    # --------------------------------------------------------
    # WI-FI PASSWORDS
    # --------------------------------------------------------

    if [[ -z "$WIFI_24_PASSWORD" ]]; then

        read -r -s \
            -p "2.4 GHz Wi-Fi password: " \
            WIFI_24_PASSWORD

        printf '\n'
    fi


    if [[ -z "$WIFI_5_PASSWORD" ]]; then

        read -r -s \
            -p "5 GHz Wi-Fi password: " \
            WIFI_5_PASSWORD

        printf '\n'
    fi

    # --------------------------------------------------------
    # ISOLATED IOT / HOME ASSISTANT
    # --------------------------------------------------------

    if [[ -z "$INSTALL_HOME_ASSISTANT_IOT" ]]; then
        local answer
        read -r -p "Configure isolated IoT Wi-Fi and Home Assistant discovery? [Y/n]: " answer
        case "$answer" in n|N|no|NO) INSTALL_HOME_ASSISTANT_IOT=0 ;; *) INSTALL_HOME_ASSISTANT_IOT=1 ;; esac
    fi

    if (( INSTALL_HOME_ASSISTANT_IOT == 1 )) && [[ -z "$HOME_ASSISTANT_IP" ]]; then
        read -r -p "Home Assistant IPv4 address [192.168.8.125]: " HOME_ASSISTANT_IP
        HOME_ASSISTANT_IP="${HOME_ASSISTANT_IP:-192.168.8.125}"
    fi

    if (( INSTALL_HOME_ASSISTANT_IOT == 1 )) && [[ -z "$IOT_WIFI_PASSWORD" ]]; then
        read -r -p "Use the 2.4 GHz Wi-Fi password for IoT Wi-Fi? [Y/n]: " answer
        case "$answer" in
            n|N|no|NO)
                read -r -s -p "IoT Wi-Fi password: " IOT_WIFI_PASSWORD
                printf '\n'
                [[ -n "$IOT_WIFI_PASSWORD" ]] || Fail_With_Message "IoT Wi-Fi password cannot be empty."
                ;;
            *) IOT_WIFI_PASSWORD="$WIFI_24_PASSWORD" ;;
        esac
    fi

    # --------------------------------------------------------
    # INTERNET-ONLY GUEST WI-FI
    # --------------------------------------------------------

    if [[ -z "$INSTALL_GUEST_WIFI" ]]; then
        read -r -p "Configure an isolated internet-only guest Wi-Fi? [Y/n]: " answer
        case "$answer" in n|N|no|NO) INSTALL_GUEST_WIFI=0 ;; *) INSTALL_GUEST_WIFI=1 ;; esac
    fi

    if (( INSTALL_GUEST_WIFI == 1 )) && [[ -z "$GUEST_WIFI_PASSWORD" ]]; then
        read -r -p "Use the 2.4 GHz Wi-Fi password for guest Wi-Fi? [y/N]: " answer
        case "$answer" in
            y|Y|yes|YES) GUEST_WIFI_PASSWORD="$WIFI_24_PASSWORD" ;;
            *)
                read -r -s -p "Guest Wi-Fi password: " GUEST_WIFI_PASSWORD
                printf '\n'
                [[ -n "$GUEST_WIFI_PASSWORD" ]] || Fail_With_Message "Guest Wi-Fi password cannot be empty."
                ;;
        esac
    fi

    # --------------------------------------------------------
    # ADGUARD HOME
    # --------------------------------------------------------

    if [[ -z "$INSTALL_ADGUARD_HOME" ]]; then
        read -r -p "Install AdGuard Home for ads and phishing/malware blocking? [Y/n]: " answer
        case "$answer" in n|N|no|NO) INSTALL_ADGUARD_HOME=0 ;; *) INSTALL_ADGUARD_HOME=1 ;; esac
    fi

    if (( INSTALL_ADGUARD_HOME == 1 )) && [[ -z "$ADGUARD_ADMIN_PASSWORD" ]]; then
        read -r -s -p "AdGuard Home admin password: " ADGUARD_ADMIN_PASSWORD
        printf '\n'
        local ADGUARD_ADMIN_PASSWORD_CONFIRM
        read -r -s -p "Confirm AdGuard Home admin password: " ADGUARD_ADMIN_PASSWORD_CONFIRM
        printf '\n'
        [[ "$ADGUARD_ADMIN_PASSWORD" == "$ADGUARD_ADMIN_PASSWORD_CONFIRM" ]] || Fail_With_Message "AdGuard Home passwords do not match."
        unset ADGUARD_ADMIN_PASSWORD_CONFIRM
    fi

    if (( INSTALL_ADGUARD_HOME == 1 )) && [[ -z "$ENFORCE_ADGUARD_DNS" ]]; then
        read -r -p "Redirect hard-coded LAN/IoT DNS requests through AdGuard? [Y/n]: " answer
        case "$answer" in n|N|no|NO) ENFORCE_ADGUARD_DNS=0 ;; *) ENFORCE_ADGUARD_DNS=1 ;; esac
    elif (( INSTALL_ADGUARD_HOME == 0 )); then
        ENFORCE_ADGUARD_DNS=0
    fi

    # --------------------------------------------------------
    # SSH PUBLIC KEY / OPTIONAL KEY-ONLY LOGIN
    # --------------------------------------------------------

    if [[ -z "$INSTALL_SSH_AUTHORIZED_KEY" ]]; then
        if [[ -n "$AUTHORIZED_SSH_KEY" ]]; then
            INSTALL_SSH_AUTHORIZED_KEY=1
        else
            read -r -p "Install an SSH public key for router login? [y/N]: " answer
            case "$answer" in y|Y|yes|YES) INSTALL_SSH_AUTHORIZED_KEY=1 ;; *) INSTALL_SSH_AUTHORIZED_KEY=0 ;; esac
        fi
    fi

    if (( INSTALL_SSH_AUTHORIZED_KEY == 1 )); then
        if [[ -z "$AUTHORIZED_SSH_KEY" ]]; then
            read -r -p "SSH public key: " AUTHORIZED_SSH_KEY
            [[ -n "$AUTHORIZED_SSH_KEY" ]] || Fail_With_Message "SSH public key cannot be empty."
        fi

        if [[ -z "$SSH_KEY_ONLY" ]]; then
            read -r -p "Disable SSH password login after installing the key? [y/N]: " answer
            case "$answer" in y|Y|yes|YES) SSH_KEY_ONLY=1 ;; *) SSH_KEY_ONLY=0 ;; esac
        fi
    else
        AUTHORIZED_SSH_KEY=""
        SSH_KEY_ONLY="${SSH_KEY_ONLY:-0}"
    fi


    # --------------------------------------------------------
    # AURORA
    # --------------------------------------------------------

    if [[ -z "${INSTALL_AURORA-}" ]]; then

        local answer

        read -r \
            -p "Install optional Aurora LuCI theme? [y/N]: " \
            answer

        case "$answer" in
            y|Y|yes|YES)
                INSTALL_AURORA=1
                ;;
            *) INSTALL_AURORA=0 ;;
        esac
    fi


    # --------------------------------------------------------
    # CUSTOM SETUP
    # --------------------------------------------------------

    if (( INSTALL_AURORA == 0 )) &&
       [[ -z "$CUSTOM_SETUP_URL" ]]; then

        local answer

        read -r \
            -p "Run a custom LuCI/theme setup script instead? [y/N]: " \
            answer

        case "$answer" in
            y|Y|yes|YES)

                read -r \
                    -p "Custom setup script URL: " \
                    CUSTOM_SETUP_URL

                [[ "$CUSTOM_SETUP_URL" =~ ^https:// ]] ||
                    Fail_With_Message \
                        "Custom setup URL must use HTTPS."

                read -r -p "Expected SHA-256 of the custom script: " CUSTOM_SETUP_SHA256
                [[ "$CUSTOM_SETUP_SHA256" =~ ^[A-Fa-f0-9]{64}$ ]] ||
                    Fail_With_Message "Custom setup SHA-256 must contain exactly 64 hexadecimal characters."
                ;;

            *)
                CUSTOM_SETUP_URL=""
                ;;
        esac
    fi


    # --------------------------------------------------------
    # TAILSCALE
    # --------------------------------------------------------

    if [[ -z "${INSTALL_TAILSCALE-}" ]]; then

        local answer

        read -r \
            -p "Install and configure Tailscale? [y/N]: " \
            answer

        case "$answer" in
            y|Y|yes|YES)
                INSTALL_TAILSCALE=1
                ;;
            *) INSTALL_TAILSCALE=0 ;;
        esac
    fi


    # --------------------------------------------------------
    # TAILSCALE LAN ACCESS / NETWORK DISCOVERY
    # --------------------------------------------------------

    INSTALL_TAILSCALE_LAN_ACCESS="${INSTALL_TAILSCALE_LAN_ACCESS:-}"
    TAILSCALE_REMOTE_ROUTERS="${TAILSCALE_REMOTE_ROUTERS-}"
    TAILSCALE_REMOTE_ROUTER_IPS="${TAILSCALE_REMOTE_ROUTER_IPS-}"

    if (( INSTALL_TAILSCALE == 1 )); then

        local answer

        if [[ -z "${INSTALL_TAILSCALE_LAN_ACCESS-}" ]]; then

            read -r \
                -p "Allow Tailscale devices to access/discover this router's LAN (${LAN_NET})? [Y/n]: " \
                answer

            case "$answer" in
                n|N|no|NO)
                    INSTALL_TAILSCALE_LAN_ACCESS=0
                    ;;
                *)
                    INSTALL_TAILSCALE_LAN_ACCESS=1
                    ;;
            esac

        fi

        if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then
            if [[ -z "$ALLOW_TAILSCALE_ROUTER_MANAGEMENT" ]]; then
                read -r -p "Allow Tailscale peers to administer this router itself? [y/N]: " answer
                case "$answer" in y|Y|yes|YES) ALLOW_TAILSCALE_ROUTER_MANAGEMENT=1 ;; *) ALLOW_TAILSCALE_ROUTER_MANAGEMENT=0 ;; esac
            fi
        else
            ALLOW_TAILSCALE_ROUTER_MANAGEMENT=0
        fi


        # --------------------------------------------------------
        # REMOTE TAILSCALE ROUTERS
        # --------------------------------------------------------

        if [[ -z "$ENABLE_TAILSCALE_REMOTE_ROUTERS" ]]; then
            read -r -p "Accept subnet routes advertised by other Tailscale routers? [y/N]: " answer
            case "$answer" in y|Y|yes|YES) ENABLE_TAILSCALE_REMOTE_ROUTERS=1 ;; *) ENABLE_TAILSCALE_REMOTE_ROUTERS=0 ;; esac
        fi


        # --------------------------------------------------------
        # OPTIONAL LOCAL LAN ADVERTISEMENT
        # --------------------------------------------------------

        if [[ -z "${INSTALL_TAILSCALE_ROUTES-}" ]]; then

            if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then
                INSTALL_TAILSCALE_ROUTES=1
            else
                INSTALL_TAILSCALE_ROUTES=0
            fi

        elif (( INSTALL_TAILSCALE_LAN_ACCESS == 0 )); then

            INSTALL_TAILSCALE_ROUTES=0
        fi

    else

        INSTALL_TAILSCALE_ROUTES=0
        INSTALL_TAILSCALE_LAN_ACCESS=0
        ALLOW_TAILSCALE_ROUTER_MANAGEMENT=0
        TAILSCALE_REMOTE_ROUTERS=0
        TAILSCALE_REMOTE_ROUTER_IPS=""
        ENABLE_TAILSCALE_REMOTE_ROUTERS=0

    fi


    export CURRENT_ROOT_PASSWORD WIFI_COUNTRY

    Validate_Configuration

    printf '\n'

    Print_Success \
        "Configuration ready."
}
