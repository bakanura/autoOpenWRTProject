#!/bin/sh

Check_Router_Resources() {
    Print_Info "Checking router flash and memory capacity..."

    Router_Ssh \
        "INSTALL_ADGUARD_HOME=$(Shell_Quote "$INSTALL_ADGUARD_HOME") sh -s" <<'REMOTE'
set -u
overlay_free_kib="$(df -Pk /overlay 2>/dev/null | awk 'NR==2 {print $4}')"
memory_available_kib="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
[ -n "$overlay_free_kib" ] || { echo "ERROR: Could not measure overlay storage" >&2; exit 1; }
[ -n "$memory_available_kib" ] || { echo "ERROR: Could not measure available memory" >&2; exit 1; }

echo "Available overlay: $((overlay_free_kib / 1024)) MiB"
echo "Available memory:  $((memory_available_kib / 1024)) MiB"

# Leave working room for package metadata, configuration backups and upgrades.
minimum_overlay_kib=8192
[ "$INSTALL_ADGUARD_HOME" = '1' ] && minimum_overlay_kib=32768
[ "$overlay_free_kib" -ge "$minimum_overlay_kib" ] || {
    echo "ERROR: Insufficient overlay space; need at least $((minimum_overlay_kib / 1024)) MiB free before installation" >&2
    exit 1
}
[ "$memory_available_kib" -ge 49152 ] || {
    echo "ERROR: Less than 48 MiB memory is available before optional services start" >&2
    exit 1
}
REMOTE

    Print_Success "Router has sufficient installation headroom."
}
