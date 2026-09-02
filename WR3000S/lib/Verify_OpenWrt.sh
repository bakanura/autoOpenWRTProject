#!/bin/sh

Verify_OpenWrt() {
    local version

    version="$(
        Router_Ssh \
            'cat /etc/openwrt_release' |
            sed -n \
                "s/^DISTRIB_DESCRIPTION='\(.*\)'/\1/p"
    )"

    [[ -n "$version" ]] ||
        Fail_With_Message \
            "Unable to determine the OpenWrt version."

    Print_Success \
        "Detected '$version'."
}
