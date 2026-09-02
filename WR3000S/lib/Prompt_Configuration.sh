#!/bin/sh

Prompt_Configuration() {
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
    # AURORA
    # --------------------------------------------------------

    if [[ -z "$INSTALL_AURORA" ]]; then

        local answer

        read -r \
            -p "Install Aurora LuCI theme? [Y/n]: " \
            answer

        case "$answer" in
            n|N|no|NO)
                INSTALL_AURORA=0
                ;;
            *)
                INSTALL_AURORA=1
                ;;
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

                [[ "$CUSTOM_SETUP_URL" =~ ^https?:// ]] ||
                    Fail_With_Message \
                        "Custom setup URL must start with http:// or https://."
                ;;

            *)
                CUSTOM_SETUP_URL=""
                ;;
        esac
    fi


    # --------------------------------------------------------
    # TAILSCALE
    # --------------------------------------------------------

    if [[ -z "$INSTALL_TAILSCALE" ]]; then

        local answer

        read -r \
            -p "Install Tailscale? [Y/n]: " \
            answer

        case "$answer" in
            n|N|no|NO)
                INSTALL_TAILSCALE=0
                ;;
            *)
                INSTALL_TAILSCALE=1
                ;;
        esac
    fi


    # --------------------------------------------------------
    # TAILSCALE LAN ACCESS / NETWORK DISCOVERY
    # --------------------------------------------------------

    INSTALL_TAILSCALE_LAN_ACCESS="${INSTALL_TAILSCALE_LAN_ACCESS-}"
    TAILSCALE_REMOTE_ROUTERS="${TAILSCALE_REMOTE_ROUTERS-}"
    TAILSCALE_REMOTE_ROUTER_IPS="${TAILSCALE_REMOTE_ROUTER_IPS-}"

    if (( INSTALL_TAILSCALE == 1 )); then

        local answer

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


        # --------------------------------------------------------
        # REMOTE TAILSCALE ROUTERS
        # --------------------------------------------------------

        if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then

            read -r \
                -p "Connect to other routers/LANs through Tailscale? [y/N]: " \
                answer

            case "$answer" in
                y|Y|yes|YES)

                    while true; do

                        read -r \
                            -p "How many remote Tailscale routers? " \
                            TAILSCALE_REMOTE_ROUTERS

                        [[ "$TAILSCALE_REMOTE_ROUTERS" =~ ^[1-9][0-9]*$ ]] &&
                            break

                        printf '%s\n' \
                            "Please enter a positive whole number."
                    done


                    local i
                    local remote_ip

                    for (( i=1; i<=TAILSCALE_REMOTE_ROUTERS; i++ )); do

                        while true; do

                            read -r \
                                -p "Remote router ${i} IPv4 address: " \
                                remote_ip

                            if Validate_Ip "$remote_ip"; then
                                break
                            fi

                            printf '%s\n' \
                                "Invalid IPv4 address."
                        done

                        if [[ -n "$TAILSCALE_REMOTE_ROUTER_IPS" ]]; then
                            TAILSCALE_REMOTE_ROUTER_IPS+=" "
                        fi

                        TAILSCALE_REMOTE_ROUTER_IPS+="$remote_ip"
                    done
                    ;;

                *)
                    TAILSCALE_REMOTE_ROUTERS=0
                    TAILSCALE_REMOTE_ROUTER_IPS=""
                    ;;
            esac
        fi


        # --------------------------------------------------------
        # OPTIONAL LOCAL LAN ADVERTISEMENT
        # --------------------------------------------------------

        if [[ -z "$INSTALL_TAILSCALE_ROUTES" ]]; then

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
        TAILSCALE_REMOTE_ROUTERS=0
        TAILSCALE_REMOTE_ROUTER_IPS=""

    fi


    export CURRENT_ROOT_PASSWORD WIFI_COUNTRY

    Validate_Configuration

    printf '\n'

    Print_Success \
        "Configuration ready."
}
