#!/bin/sh

Install_Tailscale() {
    if (( INSTALL_TAILSCALE == 0 )); then

        Print_Info \
            "Tailscale installation skipped."

        return 0
    fi


    Print_Info \
        "Installing Tailscale..."


    Apk_Add tailscale ||
        Fail_With_Message \
            "Failed to install Tailscale."


    Router_Ssh '
        /etc/init.d/tailscale enable
        /etc/init.d/tailscale start
    ' || Fail_With_Message \
        "Failed to enable/start Tailscale."


    Print_Success \
        "Tailscale service started."


    local tailscale_ip=""
    local attempt


    # --------------------------------------------------------
    # Check whether already authenticated.
    # --------------------------------------------------------

    for attempt in 1 2 3 4 5 6; do

        tailscale_ip="$(
            Router_Ssh '
                tailscale ip -4 2>/dev/null |
                    grep -E "^100\\." |
                    head -n 1 ||
                    true
            '
        )"


        if [[ -n "$tailscale_ip" ]]; then

            Print_Success \
                "Tailscale is authenticated: $tailscale_ip."

            return 0
        fi


        sleep 5
    done


    # --------------------------------------------------------
    # Authentication required.
    # --------------------------------------------------------

    Print_Info \
        "Tailscale authentication is required."


    Router_Ssh '
        tailscale up
    ' || true


    printf '\n'


    Print_Info \
        "If Tailscale printed an authentication URL above, open it in a browser."


    printf '\n'


    for attempt in $(seq 1 12); do

        tailscale_ip="$(
            Router_Ssh '
                tailscale ip -4 2>/dev/null |
                    grep -E "^100\\." |
                    head -n 1 ||
                    true
            '
        )"


        if [[ -n "$tailscale_ip" ]]; then

            Print_Success \
                "Tailscale authenticated: $tailscale_ip."

            return 0
        fi


        Print_Info \
            "Waiting for Tailscale authentication ($attempt/12)..."


        sleep 5
    done


    Fail_With_Message \
        "Tailscale was installed but did not become authenticated."
}
