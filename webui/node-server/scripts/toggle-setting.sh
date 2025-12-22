#!/usr/bin/env bash

# MIT License

# Copyright (c) 2025 nodaddyno

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
    ["User_Consent"]="analytics"
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
    ["User_Consent"]="User Consent"
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
