#!/bin/sh

Install_Aurora() {
    Print_Info "Installing Aurora LuCI theme..."
    Apk_Add luci-app-aurora-config luci-theme-aurora ||
        Fail_With_Message "Failed to install Aurora packages."
    Router_Ssh '
        uci set luci.main.mediaurlbase="/luci-static/aurora"
        uci commit luci
    ' || Fail_With_Message "Failed to activate Aurora theme."
    Print_Success "Aurora LuCI theme installed."
}
