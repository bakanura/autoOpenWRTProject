#!/bin/sh

Install_Network_Audit() {
    Print_Info "Installing read-only network security audit command..."
    Router_Ssh 'umask 022; cat > /usr/sbin/network-audit && chmod 0755 /usr/sbin/network-audit' \
        < "$SCRIPT_DIR/router-bin/network-audit" ||
        Fail_With_Message "Failed to install network-audit."
    Print_Success "Installed /usr/sbin/network-audit."
}
