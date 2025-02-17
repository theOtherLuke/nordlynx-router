#!/usr/bin/env bash

license(){
    echo -e '\e[1;32m'
    cat <<EOF
MIT License

Copyright (c) 2025 nodaddyno

Permission is hereby granted, free of charge, to any person obtaining a
     copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
                      the following conditions:

The above copyright notice and this permission notice shall be included
        in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
       SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF
    echo -e '\e[0m'
}

clear && license && sleep 1

declare -A n_settings_actions_template=(
        ["Firewall"]="firewall"
        ["Routing"]="routing"
        ["Analytics"]="analytics"
        ["Kill Switch"]="killswitch"
        ["Threat Protection Lite"]="tpl"
        ["Notify"]="notify"
        ["Tray"]="tray"
        ["Auto-connect"]="autoconnect"
        ["IPv6"]="ipv6"
        ["Meshnet"]="meshnet"
        ["DNS"]="dns"
        ["LAN Discovery"]="lan-discovery"
        ["Virtual Location"]="virtual-location"
        ["Post-quantum VPN"]="pq"
)

declare -A n_settings_actor=(
        ["firewall"]="off"
        ["routing"]="off"
        ["analytics"]="off"
        ["killswitch"]="off"
        ["tpl"]="off"
        ["notify"]="off"
        ["tray"]="off"
        ["autoconnect"]="off"
        ["ipv6"]="off"
        ["meshnet"]="off"
        ["dns"]="off"
        ["lan-discovery"]="off"
        ["virtual-location"]="off"
        ["pq"]="off"
)

declare -a n_settings_query_list

populate-query() {
        while IFS=":" read -r key value ; do
                onoff=
                if [[ $value =~ (enabled) ]]; then
                        onoff="on"
                elif [[ $value =~ (disabled) ]]; then
                        onoff="off"
                fi
                if [[ ${!n_settings_actions_template[*]} =~ ($key) ]]; then # make sure the key we have is in the template array
                        n_settings_query_list+=("${key}" "${value}" "${onoff}")
                fi
        done < <(nordvpn settings)
}

populate-query

wt_title="NordVPN Settings"
wt_prompt="
Please choose which settings to enable.

All unselected settings will be disabled"

mapfile -t chosen_settings < <(whiptail --title "${wt_title}" --checklist "${wt_prompt}" 0 0 0 --separate-output --nocancel "${n_settings_query_list[@]}" 3>&1 1>&2 2>&3)

for setting in "${chosen_settings[@]}"; do
        n_settings_actor["${n_settings_actions_template[${setting}]}"]="on"
done

for setting in "${!n_settings_actor[@]}"; do
        nordvpn set "${setting}" "${n_settings_actor[${setting}]}"
done
