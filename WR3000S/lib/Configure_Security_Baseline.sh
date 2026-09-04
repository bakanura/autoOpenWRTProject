#!/bin/sh

Configure_Security_Baseline() {
    Print_Info "Applying lean security and network-noise baseline..."

    local remote_script
    remote_script="$(mktemp)"
    cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -u
die() { echo "ERROR: $*" >&2; exit 1; }

# Validate lockout-sensitive input before staging any configuration changes.
if [ "$SSH_KEY_ONLY" = '1' ] && [ -z "$AUTHORIZED_SSH_KEY" ]; then
    die "SSH_KEY_ONLY=1 requires AUTHORIZED_SSH_KEY"
fi
if [ -n "$AUTHORIZED_SSH_KEY" ]; then
    case "$AUTHORIZED_SSH_KEY" in
        ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-nistp256\ *|ecdsa-sha2-nistp384\ *|ecdsa-sha2-nistp521\ *) ;;
        *) die "Authorized SSH key has an unsupported format" ;;
    esac
    key_payload="$(printf '%s\n' "$AUTHORIZED_SSH_KEY" | awk '{print $2}')"
    printf '%s' "$key_payload" | grep -Eq '^[A-Za-z0-9+/]+={0,2}$' || die "Authorized SSH key payload is invalid"
fi

# Use firewall4's normal policy machinery; do not inject redundant nft rules.
uci set firewall.@defaults[0].syn_flood='1' || die "Could not enable SYN flood protection"
uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'

for zone_section in $(uci show firewall 2>/dev/null | sed -n 's/^firewall\.\([^.=]*\)=zone$/\1/p'); do
    zone_name="$(uci -q get "firewall.$zone_section.name")"
    case "$zone_name" in
        wan) uci set "firewall.$zone_section.input=DROP"; uci set "firewall.$zone_section.forward=DROP" ;;
        iot|guest) uci set "firewall.$zone_section.input=REJECT"; uci set "firewall.$zone_section.forward=REJECT" ;;
    esac
done

# Lightweight dnsmasq protections confirmed compatible with the healthy setup.
uci set dhcp.@dnsmasq[0].domainneeded='1'
uci set dhcp.@dnsmasq[0].boguspriv='1'
uci set dhcp.@dnsmasq[0].rebind_protection='1'
uci set dhcp.@dnsmasq[0].rebind_localhost='1'
uci set dhcp.@dnsmasq[0].localservice='1'
uci set dhcp.@dnsmasq[0].authoritative='1'

# Eliminate 802.11b basic rates without disabling ordinary 2.4 GHz clients.
uci set wireless.radio0.legacy_rates='0'

# IGMP snooping is opt-in because some smart-home clients mishandle it.
LAN_BRIDGE_SECTION=''
for device_section in $(uci show network 2>/dev/null | sed -n 's/^network\.\([^.=]*\)=device$/\1/p'); do
    [ "$(uci -q get "network.$device_section.name")" = 'br-lan' ] && LAN_BRIDGE_SECTION=$device_section
done
[ -n "$LAN_BRIDGE_SECTION" ] || die "Could not resolve br-lan device section"
if [ "$ENABLE_IGMP_SNOOPING" = '1' ]; then
    uci set "network.$LAN_BRIDGE_SECTION.igmp_snooping=1"
else
    uci -q delete "network.$LAN_BRIDGE_SECTION.igmp_snooping"
fi

# Dropbear remains recoverable unless a public key was actually installed.
uci set dropbear.@dropbear[0].Interface='lan'
uci set dropbear.@dropbear[0].Port='22'
uci set dropbear.@dropbear[0].GatewayPorts='0'
uci set dropbear.@dropbear[0].MaxAuthTries='3'

if [ -n "$AUTHORIZED_SSH_KEY" ]; then
    mkdir -p /etc/dropbear || die "Could not create Dropbear directory"
    touch /etc/dropbear/authorized_keys || die "Could not create authorized_keys"
    grep -Fqx "$AUTHORIZED_SSH_KEY" /etc/dropbear/authorized_keys || printf '%s\n' "$AUTHORIZED_SSH_KEY" >> /etc/dropbear/authorized_keys
    chmod 0600 /etc/dropbear/authorized_keys
    grep -Fqx "$AUTHORIZED_SSH_KEY" /etc/dropbear/authorized_keys || die "Could not verify installed SSH key"
fi

if [ "$SSH_KEY_ONLY" = '1' ]; then
    [ -n "$AUTHORIZED_SSH_KEY" ] || die "SSH_KEY_ONLY=1 requires AUTHORIZED_SSH_KEY"
    grep -Fqx "$AUTHORIZED_SSH_KEY" /etc/dropbear/authorized_keys || die "Refusing key-only mode without verified key"
    # Keep password recovery active until the workstation proves it possesses
    # the matching private key in a completely separate SSH connection.
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
else
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
fi

# Preserve the existing certificate and listener policy; enforce cheap uHTTPd
# protections without regenerating certificates or blocking trusted VPN access.
uci set uhttpd.main.redirect_https='1'
uci set uhttpd.main.rfc1918_filter='1'

fw4 check || die "Firewall validation failed before commit"
uci commit firewall || die "Could not commit firewall"
uci commit dhcp || die "Could not commit DHCP/DNS"
uci commit wireless || die "Could not commit wireless"
uci commit network || die "Could not commit network"
uci commit dropbear || die "Could not commit Dropbear"
uci commit uhttpd || die "Could not commit uHTTPd"

/etc/init.d/dnsmasq reload || die "Could not reload dnsmasq"
/etc/init.d/firewall reload || die "Could not reload firewall"
wifi reload || die "Could not reload Wi-Fi"
/etc/init.d/dropbear restart || die "Could not restart Dropbear"
/etc/init.d/uhttpd reload || die "Could not reload uHTTPd"
fw4 check || die "Firewall validation failed after reload"
REMOTE

    if ! Router_Ssh \
        "ENABLE_IGMP_SNOOPING=$(Shell_Quote "$ENABLE_IGMP_SNOOPING") \
         SSH_KEY_ONLY=$(Shell_Quote "$SSH_KEY_ONLY") \
         AUTHORIZED_SSH_KEY=$(Shell_Quote "$AUTHORIZED_SSH_KEY") \
         sh -s" < "$remote_script"; then
        rm -f "$remote_script"
        Fail_With_Message "Failed to apply security baseline."
    fi
    rm -f "$remote_script"

    if (( SSH_KEY_ONLY == 1 )); then
        if ! ssh "${SSH_OPTS[@]}" \
            -o BatchMode=yes \
            -o PreferredAuthentications=publickey \
            -o PasswordAuthentication=no \
            -o KbdInteractiveAuthentication=no \
            -o ControlMaster=no \
            -o ControlPath=none \
            "root@$CURRENT_ROUTER_IP" true; then
            Fail_With_Message "The installed SSH public key could not authenticate; password login remains enabled."
        fi

        Router_Ssh '
            uci set dropbear.@dropbear[0].PasswordAuth="off"
            uci set dropbear.@dropbear[0].RootPasswordAuth="off"
            uci commit dropbear
            /etc/init.d/dropbear restart
        ' || Fail_With_Message "Public-key login worked, but key-only mode could not be activated."

        Print_Success "Security baseline applied; SSH is LAN-only and key-only."
    else
        Print_Warning "SSH is LAN-only, but password login remains enabled to prevent lockout."
    fi
}
