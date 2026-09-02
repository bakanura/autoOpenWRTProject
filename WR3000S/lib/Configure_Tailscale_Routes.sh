#!/usr/bin/env bash

Configure_Tailscale_Routes() {

    (( INSTALL_TAILSCALE == 1 )) ||
        return 0

    Print_Info \
        "Configuring Tailscale networking for ${LAN_NET}..."


    # ------------------------------------------------------------
    # Local LAN advertisement
    # ------------------------------------------------------------

    if (( INSTALL_TAILSCALE_ROUTES == 1 )); then

        Router_Ssh \
            "tailscale set --advertise-routes=$(Shell_Quote "$LAN_NET")" ||
            Fail_With_Message \
                "Failed to advertise ${LAN_NET} through Tailscale."

        Print_Success \
            "Tailscale is advertising ${LAN_NET}."

    else

        Print_Info \
            "Local LAN advertisement disabled."

    fi


    # ------------------------------------------------------------
    # LAN access / discovery firewall
    # ------------------------------------------------------------

    if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 ||
          TAILSCALE_REMOTE_ROUTERS > 0 )); then

        uci -q set network.tailscale=interface
        uci -q set network.tailscale.proto='none'
        uci -q set network.tailscale.device='tailscale0'

        TS_ZONE="$(uci show firewall 2>/dev/null |
            sed -n "s/^firewall\.\(@zone\[[0-9][0-9]*\]\)\.name='tailscale'$/\1/p" |
            head -n1)"

        if [ -z "$TS_ZONE" ]; then
            TS_ZONE="$(uci add firewall zone)"
        fi

        uci set firewall."$TS_ZONE".name='tailscale'
        uci set firewall."$TS_ZONE".network='tailscale'
        uci set firewall."$TS_ZONE".input='ACCEPT'
        uci set firewall."$TS_ZONE".output='ACCEPT'
        uci set firewall."$TS_ZONE".forward='ACCEPT'
        uci set firewall."$TS_ZONE".masq='1'


        if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 ||
              TAILSCALE_REMOTE_ROUTERS > 0 )); then
            uci -q show firewall |
                grep -q "src='lan'.*dest='tailscale'" || {
                    F="$(uci add firewall forwarding)"
                    uci set firewall."$F".src='lan'
                    uci set firewall."$F".dest='tailscale'
                }
        fi

        if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then
            uci -q show firewall |
                grep -q "src='tailscale'.*dest='lan'" || {
                    F="$(uci add firewall forwarding)"
                    uci set firewall."$F".src='tailscale'
                    uci set firewall."$F".dest='lan'
                }
        fi


        # --------------------------------------------------------
        # Reverse path filtering
        # --------------------------------------------------------

        grep -qxF \
            'net.ipv4.conf.all.rp_filter=0' \
            /etc/sysctl.conf ||
            echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf

        grep -qxF \
            'net.ipv4.conf.tailscale0.rp_filter=0' \
            /etc/sysctl.conf ||
            echo 'net.ipv4.conf.tailscale0.rp_filter=0' >> /etc/sysctl.conf

        sysctl -p


        # --------------------------------------------------------
        # Persistent fw4 output allowance
        # --------------------------------------------------------

        touch /etc/rc.local

        grep -qF \
            'nft insert rule inet fw4 output oifname "tailscale0" accept 2>/dev/null' \
            /etc/rc.local ||
            sed -i '/^[[:space:]]*exit 0[[:space:]]*$/i\
nft insert rule inet fw4 output oifname "tailscale0" accept 2>/dev/null
' /etc/rc.local


        uci commit network
        uci commit firewall

        fw4 reload

    fi


    # ------------------------------------------------------------
    # Tailscale restart
    # ------------------------------------------------------------

    tailscale set --accept-routes=true ||
        Fail_With_Message "Failed to enable Tailscale route acceptance."

    /etc/init.d/tailscale restart
    sleep 2


    # ------------------------------------------------------------
    # Policy routing table 52
    # ------------------------------------------------------------

    if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then

        ip route replace \
            100.64.0.0/10 \
            dev tailscale0 \
            table 52

        ip route replace \
            "$LAN_NET" \
            dev br-lan \
            table 52

        ip rule add \
            from "$LAN_NET" \
            to 100.64.0.0/10 \
            lookup 52 \
            priority 50 \
            2>/dev/null || true

    fi


    # ------------------------------------------------------------
    # Remote Tailscale router LANs
    # ------------------------------------------------------------

    if (( TAILSCALE_REMOTE_ROUTERS > 0 )); then

        remote_index=0

        for remote_ip in $TAILSCALE_REMOTE_ROUTER_IPS; do

            remote_index=$((remote_index + 1))

            remote_prefix="${remote_ip%.*}.0/24"
            remote_priority=$((100 + remote_index - 1))

            ip route replace \
                "$remote_prefix" \
                dev tailscale0 \
                table 52

            ip rule add \
                to "$remote_prefix" \
                lookup 52 \
                priority "$remote_priority" \
                2>/dev/null || true

            Print_Success \
                "Tailscale remote LAN ${remote_prefix} configured."

        done

    fi


    ip route flush cache 2>/dev/null || true

    touch /etc/rc.local

    {
        printf '%s\n' \
            'ip route replace 100.64.0.0/10 dev tailscale0 table 52 2>/dev/null || true' \
            "ip route replace $LAN_NET dev br-lan table 52 2>/dev/null || true" \
            "ip rule add from $LAN_NET to 100.64.0.0/10 lookup 52 priority 50 2>/dev/null || true" \
            'ip rule add to 100.64.0.0/10 lookup 52 priority 50 2>/dev/null || true'

        remote_index=0

        for remote_ip in $TAILSCALE_REMOTE_ROUTER_IPS; do
            remote_index=$((remote_index + 1))
            remote_prefix="${remote_ip%.*}.0/24"
            remote_priority=$((100 + remote_index - 1))

            printf '%s\n' \
                "ip route replace $remote_prefix dev tailscale0 table 52 2>/dev/null || true" \
                "ip rule add to $remote_prefix lookup 52 priority $remote_priority 2>/dev/null || true"
        done
    } > /tmp/gjallar-tailscale-routes

    while IFS= read -r route_line; do
        [ -n "$route_line" ] || continue

        grep -qF "$route_line" /etc/rc.local || {
            sed -i "/^[[:space:]]*exit 0[[:space:]]*$/i\\
$route_line
" /etc/rc.local
        }
    done < /tmp/gjallar-tailscale-routes

    rm -f /tmp/gjallar-tailscale-routes


    # ------------------------------------------------------------
    # Runtime fw4 output allowance
    # ------------------------------------------------------------

    if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then
        nft insert rule \
            inet fw4 output \
            oifname "tailscale0" \
            accept \
            2>/dev/null || true
    fi


    # ------------------------------------------------------------
    # Sanity checks
    # ------------------------------------------------------------

    if (( INSTALL_TAILSCALE_LAN_ACCESS == 1 )); then

        echo "[Tailscale] Local LAN route sanity:"
        ip route get "$LAN_NET" from "$ROUTER_NEW"

        if (( TAILSCALE_REMOTE_ROUTERS > 0 )); then
            for remote_ip in $TAILSCALE_REMOTE_ROUTER_IPS; do
                echo "[Tailscale] Remote route sanity: $remote_ip"
                ip route get "$remote_ip" from "$ROUTER_NEW"
            done
        fi

    fi
}

