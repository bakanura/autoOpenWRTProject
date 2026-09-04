#!/bin/sh

Final_Verification() {
    Print_Info "Running final verification..."
    Verify_Final_Lan

    Router_Ssh '
        set -e
        [ "$(uci -q get attendedsysupgrade.client.login_check_for_upgrades)" = "1" ]
        test -x /usr/sbin/network-audit
        fw4 check
    ' || Fail_With_Message "Base final verification failed."

    if (( INSTALL_HOME_ASSISTANT_IOT == 1 )); then
        Router_Ssh '
            set -e
            test -x /usr/sbin/homeassistant-iot
            apk info -e avahi-nodbus-daemon >/dev/null
            grep -Fxq "allow-interfaces=br-lan,phy0-ap1" /etc/avahi/avahi-daemon.conf
            grep -Fxq "enable-reflector=yes" /etc/avahi/avahi-daemon.conf
            grep -Fxq "reflect-ipv=no" /etc/avahi/avahi-daemon.conf
            [ "$(uci -q get firewall.iot.input)" = "REJECT" ]
            [ "$(uci -q get firewall.iot.forward)" = "REJECT" ]
            [ "$(uci -q get firewall.lan_to_iot.src)" = "lan" ]
            [ "$(uci -q get firewall.lan_to_iot.dest)" = "iot" ]
            [ "$(uci -q get wireless.iot_ap.network)" = "iot" ]
            ! uci show wireless 2>/dev/null | grep -Eq "wireless\.iot_ap\.(macfilter|maclist)="
            for section in $(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.=]*\)=forwarding$/\1/p"); do
                [ "$(uci -q get "firewall.$section.src")" != "iot" ] || exit 1
            done
        ' || Fail_With_Message "IoT/Avahi final verification failed."
    fi

    if (( INSTALL_GUEST_WIFI == 1 )); then
        Router_Ssh '
            set -e
            [ "$(uci -q get firewall.guest.input)" = "REJECT" ]
            [ "$(uci -q get firewall.guest.forward)" = "REJECT" ]
            [ "$(uci -q get firewall.guest_to_wan.src)" = "guest" ]
            [ "$(uci -q get firewall.guest_to_wan.dest)" = "wan" ]
            [ "$(uci -q get wireless.guest_ap.network)" = "guest" ]
            [ "$(uci -q get wireless.guest_ap.isolate)" = "1" ]
            for section in $(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.=]*\)=forwarding$/\1/p"); do
                [ "$(uci -q get "firewall.$section.src")" != "guest" ] ||
                    [ "$(uci -q get "firewall.$section.dest")" = "wan" ] || exit 1
            done
        ' || Fail_With_Message "Guest isolation final verification failed."
    fi

    Router_Ssh '/usr/sbin/network-audit' ||
        Fail_With_Message "Network security audit failed."

    if (( INSTALL_ADGUARD_HOME == 1 )); then
        Router_Ssh '
            set -e
            /etc/init.d/adguardhome running
            [ "$(uci -q get dhcp.@dnsmasq[0].port)" = "54" ]
            grep -Eq "^[[:space:]]*protection_enabled:[[:space:]]*true" /etc/adguardhome/adguardhome.yaml
            grep -Eq "^[[:space:]]*filtering_enabled:[[:space:]]*true" /etc/adguardhome/adguardhome.yaml
            nslookup openwrt.org 127.0.0.1 >/dev/null 2>&1
        ' || Fail_With_Message "AdGuard Home final verification failed."
    fi

    if (( INSTALL_AURORA == 1 )); then
        Router_Ssh '
            set -e
            [ "$(uci -q get luci.main.mediaurlbase)" = "/luci-static/aurora" ]
            [ "$(uci -q get luci.themes.Aurora)" = "/luci-static/aurora" ]
            test -f /usr/share/ucode/luci/template/themes/aurora/header.ut
            test -f /usr/share/ucode/luci/template/themes/aurora/footer.ut
            test -f /usr/share/ucode/luci/template/themes/aurora/sysauth.ut
            test -d /www/luci-static/aurora
        ' || Fail_With_Message "Final Aurora verification failed."
    fi

    if (( INSTALL_TAILSCALE == 1 )); then
        Router_Ssh 'tailscale ip -4 2>/dev/null | grep -Eq "^100\\."' ||
            Fail_With_Message "Final Tailscale verification failed."
    fi

    Print_Success "Final verification passed."
}
