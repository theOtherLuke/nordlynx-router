#!/usr/bin/env bash
args="$1"
declare -A settings=(
    ["Technology"]="technology"
    ["Firewall"]="firewall"
    ["Firewall_Mark"]="firewall-mark"
    ["Routing"]="routing"
    ["Analytics"]="analytics"
    ["Kill_Switch"]="killswitch"
    ["Threat_Protection_Lite"]="tpl"
    ["Notify"]="notify"
    ["Tray"]="tray"
    ["Auto-connect"]="autoconnect"
    ["IPv6"]="ipv6"
    ["Meshnet"]="meshnet"
    ["DNS"]="dns"
    ["LAN_Discovery"]="lan-discovery"
    ["Virtual_Location"]="virtual-location"
    ["Post-quantum_VPN"]="pq"
)
declare -A settingsGreps=(
    ["Technology"]="Technology"
    ["Firewall"]="Firewall"
    ["Firewall_Mark"]="Firewall Mark"
    ["Routing"]="Routing"
    ["Analytics"]="Analytics"
    ["Kill_Switch"]="Kill Switch"
    ["Threat_Protection_Lite"]="Threat Protection Lite"
    ["Notify"]="Notify"
    ["Tray"]="Tray"
    ["Auto-connect"]="Auto-connect"
    ["IPv6"]="IPv6"
    ["Meshnet"]="Meshnet"
    ["DNS"]="dns"
    ["LAN_Discovery"]="Lan Discovery"
    ["Virtual_Location"]="Virtual Location"
    ["Post-quantum_VPN"]="Post-quantum VPN"
)

echo "Toggling setting ${settingsGreps[$args]}"
currentSetting="$(nordvpn settings | grep -i "${settingsGreps[$args]}")"
case "${currentSetting,,}" in
    *enabled)
        echo "Disabling ${settingsGreps[$args]}"
        nordvpn set ${settings[$args]} off
        ;;
    *disabled) 
        echo "Enabling ${settingsGreps[$args]}"
        nordvpn set ${settings[$args]} on
        ;;
esac
