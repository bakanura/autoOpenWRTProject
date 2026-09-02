#!/bin/sh

Configure_Attended_Sysupgrade() {
    Print_Info \
        "Configuring attended sysupgrade..."


    Router_Ssh '
        uci set \
            attendedsysupgrade.client.login_check_for_upgrades="1"

        uci commit attendedsysupgrade
    ' || Fail_With_Message \
        "Failed to configure attended sysupgrade."


    Router_Ssh '
        [ "$(uci -q get \
            attendedsysupgrade.client.login_check_for_upgrades)" = "1" ]
    ' || Fail_With_Message \
        "Attended sysupgrade verification failed."


    Print_Success \
        "Attended sysupgrade configured."
}
