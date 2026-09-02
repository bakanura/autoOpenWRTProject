#!/usr/bin/env bash

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

# Empty = prompt.
# 1 = install
# 0 = skip
INSTALL_AURORA="${INSTALL_AURORA-}"

# Only used when Aurora is disabled.
CUSTOM_SETUP_URL="${CUSTOM_SETUP_URL-}"

# Empty = prompt.
# 1 = install
# 0 = skip
INSTALL_TAILSCALE="${INSTALL_TAILSCALE-}"

# Empty = prompt when Tailscale is enabled.
# 1 = advertise LAN
# 0 = skip
INSTALL_TAILSCALE_ROUTES="${INSTALL_TAILSCALE_ROUTES-}"
INSTALL_TAILSCALE_LAN_ACCESS="${INSTALL_TAILSCALE_LAN_ACCESS-}"
TAILSCALE_REMOTE_ROUTERS="${TAILSCALE_REMOTE_ROUTERS-}"
TAILSCALE_REMOTE_ROUTER_IPS="${TAILSCALE_REMOTE_ROUTER_IPS-}"


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
# OUTPUT
# ============================================================











# ============================================================
# CLEANUP
# ============================================================


trap Cleanup EXIT INT TERM


# ============================================================
# SHELL QUOTING
# ============================================================



# ============================================================
# IP VALIDATION
# ============================================================



# ============================================================
# CONFIGURATION VALIDATION
# ============================================================



# ============================================================
# PROMPTS
# ============================================================



# ============================================================
# SSH
# ============================================================













# ============================================================
# OPENWRT
# ============================================================



# ============================================================
# LAN HELPERS
# ============================================================















# ============================================================
# LAN MIGRATION / REPAIR
# ============================================================



# ============================================================
# FINAL LAN VERIFICATION
# ============================================================



# ============================================================
# ROOT PASSWORD
# ============================================================



# ============================================================
# WI-FI
# ============================================================



# ============================================================
# WAN
# ============================================================









# ============================================================
# APK
# ============================================================





# ============================================================
# ATTENDED SYSUPGRADE
# ============================================================



# ============================================================
# AURORA
# ============================================================



# ============================================================
# CUSTOM SETUP
# ============================================================



# ============================================================
# TAILSCALE
# ============================================================



# ============================================================
# TAILSCALE ROUTES
# ============================================================



# ============================================================
# FINAL VERIFICATION
# ============================================================



# ============================================================

# Load functions
for f in ./lib/*.sh; do
    . "$f"
done

trap Cleanup EXIT INT TERM

# MAIN
# ============================================================

Prompt_Configuration

Prepare_Ssh

# MUST happen before any Router_Ssh call.
Connect_To_Router

Verify_OpenWrt

# LAN migration/repair happens before package installation.
Migrate_Lan

Verify_Final_Lan

# Internet is required before package downloads.
Wait_For_Wan

Change_Root_Password

Configure_Wifi

Configure_Attended_Sysupgrade

# OpenWrt 25.12+ uses apk.
Apk_Update

if (( INSTALL_AURORA == 1 )); then
    Install_Aurora
fi

if (( INSTALL_AURORA == 0 )); then
    Install_Custom_Setup
fi

Install_Tailscale

Configure_Tailscale_Routes

Final_Verification


# ============================================================
# COMPLETE
# ============================================================

printf '\n'

printf '%s\n' \
    '============================================================'


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
