#!/bin/sh

Final_Verification() {
    Print_Info \
        "Running final verification..."


    # --------------------------------------------------------
    # LAN
    # --------------------------------------------------------

    Verify_Final_Lan


    # --------------------------------------------------------
    # ATTENDED SYSUPGRADE
    # --------------------------------------------------------

    Router_Ssh '
        [ "$(uci -q get \
            attendedsysupgrade.client.login_check_for_upgrades)" = "1" ]
    ' || Fail_With_Message \
        "Attended sysupgrade final verification failed."


    Print_Success \
        "Attended sysupgrade verification passed."


    # --------------------------------------------------------
    # AURORA
    # --------------------------------------------------------

    if (( INSTALL_AURORA == 1 )); then

        Router_Ssh '
            set -e

            [ "$(uci -q get luci.main.mediaurlbase)" = "/luci-static/aurora" ]

            [ "$(uci -q get luci.themes.Aurora)" = "/luci-static/aurora" ]

            test -f \
                /usr/share/ucode/luci/template/themes/aurora/header.ut

            test -f \
                /usr/share/ucode/luci/template/themes/aurora/footer.ut

            test -f \
                /usr/share/ucode/luci/template/themes/aurora/sysauth.ut

            test -d \
                /www/luci-static/aurora
        ' || Fail_With_Message \
            "Final Aurora verification failed."


        Print_Success \
            "Aurora verification passed."
    fi


    # --------------------------------------------------------
    # TAILSCALE
    # --------------------------------------------------------

    if (( INSTALL_TAILSCALE == 1 )); then

        Router_Ssh '
            tailscale ip -4 2>/dev/null |
                grep -Eq "^100\\."
        ' || Fail_With_Message \
            "Final Tailscale verification failed."


        Print_Success \
            "Tailscale verification passed."


        if (( INSTALL_TAILSCALE_ROUTES == 1 )); then

            Print_Info \
                "Configured advertised route: $LAN_NET"

            Router_Ssh '
                tailscale status --json 2>/dev/null |
                    grep -Fq \
                        "\"AdvertiseRoutes\"" ||
                    true
            '
        fi
    fi


    Print_Success \
        "Final verification passed."
}
