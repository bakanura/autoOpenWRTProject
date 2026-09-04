#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# WR3000S FULL OPENWRT SETUP
# Cudy WR3000S v1
# OpenWrt 25.12+
#
# Pre-fill any variables before running.
# Prompt_Configuration only asks for values that are empty.
#
# IMPORTANT:
# Do not commit this file with real passwords.
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

ROUTER_OLD="${ROUTER_OLD-192.168.1.1}"
ROUTER_NEW="${ROUTER_NEW-192.168.8.1}"

# Empty is VALID.
# Fresh OpenWrt installations can have an empty root password.
CURRENT_ROOT_PASSWORD="${CURRENT_ROOT_PASSWORD-}"

# Empty = prompt.
ROOT_PASSWORD="${ROOT_PASSWORD-}"

WIFI_24_SSID="${WIFI_24_SSID-bakasifu-2.4ghz}"
WIFI_24_PASSWORD="${WIFI_24_PASSWORD-}"

WIFI_5_SSID="${WIFI_5_SSID-bakasifu-5ghz}"
WIFI_5_PASSWORD="${WIFI_5_PASSWORD-}"

WIFI_COUNTRY="${WIFI_COUNTRY-}"

IOT_WIFI_SSID="${IOT_WIFI_SSID-bakasifu-IoT}"
# Defaults to the 2.4 GHz password after prompting when left empty.
IOT_WIFI_PASSWORD="${IOT_WIFI_PASSWORD-}"
HOME_ASSISTANT_IP="${HOME_ASSISTANT_IP-}"
INSTALL_HOME_ASSISTANT_IOT="${INSTALL_HOME_ASSISTANT_IOT-}"

INSTALL_GUEST_WIFI="${INSTALL_GUEST_WIFI-}"
GUEST_WIFI_SSID="${GUEST_WIFI_SSID-bakasifu-Guest}"
GUEST_WIFI_PASSWORD="${GUEST_WIFI_PASSWORD-}"

# Opt-in because IGMP snooping needs runtime compatibility testing with IoT gear.
ENABLE_IGMP_SNOOPING="${ENABLE_IGMP_SNOOPING-0}"
# Paste one public key here or export it. Never use a private key.
AUTHORIZED_SSH_KEY="${AUTHORIZED_SSH_KEY-}"
INSTALL_SSH_AUTHORIZED_KEY="${INSTALL_SSH_AUTHORIZED_KEY-}"
SSH_KEY_ONLY="${SSH_KEY_ONLY-}"

INSTALL_ADGUARD_HOME="${INSTALL_ADGUARD_HOME-}"
ADGUARD_ADMIN_USER="${ADGUARD_ADMIN_USER-admin}"
ADGUARD_ADMIN_PASSWORD="${ADGUARD_ADMIN_PASSWORD-}"
ENFORCE_ADGUARD_DNS="${ENFORCE_ADGUARD_DNS-}"

# Empty = prompt.
# 1 = install
# 0 = skip
INSTALL_AURORA="${INSTALL_AURORA-}"

# Only used when Aurora is disabled.
CUSTOM_SETUP_URL="${CUSTOM_SETUP_URL-}"
CUSTOM_SETUP_SHA256="${CUSTOM_SETUP_SHA256-}"

# Empty = prompt.
# 1 = install
# 0 = skip
INSTALL_TAILSCALE="${INSTALL_TAILSCALE-}"

# Empty = prompt when Tailscale is enabled.
# 1 = advertise LAN
# 0 = skip
INSTALL_TAILSCALE_ROUTES="${INSTALL_TAILSCALE_ROUTES-}"

INSTALL_TAILSCALE_LAN_ACCESS="${INSTALL_TAILSCALE_LAN_ACCESS-}"
ALLOW_TAILSCALE_ROUTER_MANAGEMENT="${ALLOW_TAILSCALE_ROUTER_MANAGEMENT-}"

TAILSCALE_REMOTE_ROUTERS="${TAILSCALE_REMOTE_ROUTERS-}"
TAILSCALE_REMOTE_ROUTER_IPS="${TAILSCALE_REMOTE_ROUTER_IPS-}"
ENABLE_TAILSCALE_REMOTE_ROUTERS="${ENABLE_TAILSCALE_REMOTE_ROUTERS-}"

# ============================================================
# LOAD LIBRARY FUNCTIONS
# ============================================================

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Explicit allowlist: never execute an unrelated file merely because it was
# copied into lib/. Order keeps foundational helpers available to dependents.
for lib in \
    Print_Info.sh Print_Error.sh Print_Success.sh Print_Warning.sh \
    Fail_With_Message.sh Shell_Quote.sh Validate_Ip_Address.sh \
    Validate_Configuration.sh Prompt_Configuration.sh Cleanup.sh \
    Prepare_Ssh.sh Router_Ssh.sh Can_Ssh.sh Open_Ssh_Master.sh \
    Close_Ssh_Master.sh Connect_To_Router.sh Verify_OpenWrt.sh \
    Verify_New_Lan_On_Router.sh Verify_New_Lan_Reachable.sh \
    Verify_New_Lan_Uci.sh Verify_Old_Lan_Uci.sh Wait_For_New_Ssh.sh \
    Migrate_Lan.sh Verify_Final_Lan.sh Get_Wan_Ip.sh Has_Default_Route.sh \
    Test_Router_Internet.sh Wait_For_Wan.sh Check_Router_Resources.sh \
    Change_Root_Password.sh Configure_Wifi.sh Configure_Attended_Sysupgrade.sh \
    Apk_Add.sh Apk_Update.sh Configure_HomeAssistant_IoT.sh Configure_Guest.sh \
    Configure_Security_Baseline.sh Configure_AdGuardHome.sh \
    Install_Network_Audit.sh Install_Aurora.sh Install_Custom_Setup.sh \
    Install_Tailscale.sh Configure_Tailscale_Routes.sh Final_Verification.sh
do
    source "$SCRIPT_DIR/lib/$lib"
done

# ============================================================
# DERIVED VALUES
# ============================================================

LAN_NET="${ROUTER_NEW%.*}.0/24"

SSH_CONTROL_DIR=""
SSH_CONTROL_SOCKET=""
SSH_ASKPASS_FILE=""
SSH_PASSWORD_FILE=""

CURRENT_ROUTER_IP=""
FIRST_IP_FAILED=0

SSH_OPTS=()

# ============================================================
# CLEANUP
# ============================================================

trap Cleanup EXIT INT TERM

# ============================================================
# MAIN
# ============================================================

Prompt_Configuration

if [[ -z "$IOT_WIFI_PASSWORD" ]]; then
    IOT_WIFI_PASSWORD="$WIFI_24_PASSWORD"
fi

if [[ -z "$GUEST_WIFI_PASSWORD" ]]; then
    GUEST_WIFI_PASSWORD="$WIFI_24_PASSWORD"
fi

Prepare_Ssh

# MUST happen before any Router_Ssh call.
Connect_To_Router

Verify_OpenWrt

# LAN migration/repair happens before package installation.
Migrate_Lan
Verify_Final_Lan

# Internet is required before package downloads.
Wait_For_Wan
Check_Router_Resources

Change_Root_Password
Configure_Wifi
Configure_Attended_Sysupgrade

# OpenWrt 25.12+ uses apk.
Apk_Update
if (( INSTALL_HOME_ASSISTANT_IOT == 1 )); then
    Configure_HomeAssistant_IoT
fi
if (( INSTALL_GUEST_WIFI == 1 )); then
    Configure_Guest
fi
Configure_Security_Baseline
Configure_AdGuardHome
Install_Network_Audit

if (( INSTALL_AURORA == 1 )); then
    Install_Aurora
fi

if (( INSTALL_AURORA == 0 )); then
    Install_Custom_Setup
fi

Install_Tailscale
Configure_Tailscale_Routes

Verify_Wifi_Active
Final_Verification

# ============================================================
# COMPLETE
# ============================================================

printf '\n'
printf '%s\n' \
    '============================================================'

printf '%s\n' \
    "Resource check: ssh root@${ROUTER_NEW} network-audit --resources"

Print_Success \
    "WR3000S setup complete."

printf '%s\n' \
    "LuCI: http://${ROUTER_NEW}/"

printf '%s\n' \
    "LAN:  ${ROUTER_NEW}/24"

printf '%s\n' \
    "SSID 2.4 GHz: ${WIFI_24_SSID}"

printf '%s\n' \
    "SSID 5 GHz:   ${WIFI_5_SSID}"

if (( INSTALL_HOME_ASSISTANT_IOT == 1 )); then
    printf '%s\n' "SSID IoT:     ${IOT_WIFI_SSID}"
    printf '%s\n' "Home Assistant: ${HOME_ASSISTANT_IP}:8123"
fi

if (( INSTALL_GUEST_WIFI == 1 )); then
    printf '%s\n' "SSID Guest:   ${GUEST_WIFI_SSID} (internet only)"
fi

if (( INSTALL_ADGUARD_HOME == 1 )); then
    printf '%s\n' "AdGuard Home: http://${ROUTER_NEW}:8080/"
fi

if (( INSTALL_AURORA == 1 )); then
    printf '%s\n' \
        "Aurora: installed and activated"
fi

if (( INSTALL_TAILSCALE == 1 )); then
    printf '%s\n' \
        "Tailscale: installed"
fi

if (( INSTALL_TAILSCALE_ROUTES == 1 )); then
    printf '%s\n' \
        "Tailscale route: ${LAN_NET}"
fi

printf '%s\n' \
    '============================================================'
