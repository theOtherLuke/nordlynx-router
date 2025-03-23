#!/usr/bin/env bash
license='
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


'

declare -a my_interfaces
declare -a my_interface_prompt
declare -a countries
countries_temp=$(nordvpn countries)
for c in $countries_temp; do
    countries+=("$c" "")
done
declare -a groups
groups_temp=$(nordvpn groups)
for g in $groups_temp; do
    groups+=("$g" "")
done
country=""
group=""
connect_options=
wan_interface=
lan_interface=
sys_interfaces=$(ls /sys/class/net)
wt_title="NordVPN Router - Monitor Service Setup"
whiptail --title "${wt_title}" --infobox "${license}" 0 0
sleep 1

for interface in $sys_interfaces; do
    if [[ $interface =~ ^([e][no|th|ns|np]) ]]; then
        my_interfaces+=("$interface")
    fi
done
for i in "${my_interfaces[@]}"; do
    my_interface_prompt+=("$i" "")
done

user-settings-prompt() {
    cat <<EOF
WAN Interface    : ${wan_interface}
LAN Interface    : ${lan_interface}

Are these settings correct?

EOF
}

get-wan-interface() {
    while :; do
        wt_prompt="Select the WAN interface"
        wan_interface=$(whiptail --title "${wt_title}" --menu "${wt_prompt}" 0 50 0 "${my_interface_prompt[@]}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            for (( i=0; i<${#my_interface_prompt[@]}; i+=2 )); do
                if [[ ${my_interface_prompt[$i]} =~ $wan_interface ]]; then
                    if [[ ${my_interface_prompt[$i]} =~ (LAN) ]]; then
                        lan_interface=""
                    fi
                    my_interface_prompt[$((i+1))]="WAN"
                elif [[ ! ${my_interface_prompt[$i]} =~ $lan_interface ]]; then
                    my_interface_prompt[(($i+1))]=""
                fi
            done
            return
        else
            exit
        fi
    done
}

get-lan-interface() {
    while :; do
        wt_prompt="Select the LAN interface"
        lan_interface=$(whiptail --title "${wt_title}" --menu "${wt_prompt}" 0 50 0 "${my_interface_prompt[@]}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            for (( i=0; i<${#my_interface_prompt[@]}; i+=2 )); do
                if [[ ${my_interface_prompt[$i]} =~ $lan_interface ]]; then
                    if [[ ${my_interface_prompt[$i]} =~ (WAN) ]]; then
                        wan_interface=""
                    fi
                    my_interface_prompt[$((i+1))]="LAN"
                elif [[ ! ${my_interface_prompt[$i]} =~ $wan_interface ]]; then
                    my_interface_prompt[(($i+1))]=""
                fi
            done
            return
        else
            exit
        fi
    done
}

choose-group() {
    choice=$(whiptail --title "${wt_title}" --menu "Choose a group..." 0 50 0 "${groups[@]}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
        group="$choice"
    fi
}

choose-country() {
    choice=$(whiptail --title "${wt_title}" --menu "Choose a country..." 0 50 0 "${countries[@]}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
        country="$choice"
    fi
}

perform-installation() {
    echo -e "XXX\n0\nFetching /etc/systemd/system/nordvpn-net-monitor.service\nXXX"
    wget -qO /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/nordvpn-net-monitor.service
    echo -e "XXX\n10\nFetching /root/connect-nord.sh\nXXX"
    wget -qO /root/connect-nord.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/connect-nord.sh
    echo -e "XXX\n20\nFetching /root/connect-nord.conf\nXXX"
    wget -qO /root/connect-nord.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/connect-nord.conf
    echo -e "XXX\n40\nMaking /root/connect-nord.sh executable\nXXX"
    chmod +x /root/connect-nord.sh &> /dev/null
    echo -e "XXX\n60\nWriting settings to /root/connect-nord.conf\nXXX"
    sed -i "s/wan_interface/$wan_interface/g" /root/connect-nord.conf &> /dev/null
    sed -i "s/lan_interface/$lan_interface/g" /root/connect-nord.conf &> /dev/null
    if [[ -n $group || -n $country ]]; then
        if [[ -n $group && -n $country ]]; then
            connect_options="-g ${group} ${country}"
        else
            connect_options="${group}${country}"
        fi
        sed -i "s/c_options/$connect_options/g" /root/connect-nord.conf
    else
        sed -i "s/c_options//g" /root/connect-nord.conf
    fi
    echo -e "XXX\n80\nEnabling /etc/systemd/system/nordvpn-net-monitor.service\nXXX"
    systemctl daemon-reload &> /dev/null
    systemctl enable nordvpn-net-monitor.service &> /dev/null
    echo -e "XXX\n100\nDone!\nXXX"
    sleep 2
}

while :; do
    get-wan-interface
    if [[ -n $lan_interface && -n $wan_interface && $wan_interface != $lan_interface ]]; then
        wt_prompt=$(user-settings-prompt)
        if whiptail --title "${wt_title}" --yesno "${wt_prompt}" 0 0 3>&1 1>&2 2>&3; then
            break
        fi
    fi
    get-lan-interface
    if [[ -n $lan_interface && -n $wan_interface && $wan_interface != $lan_interface ]]; then
        wt_prompt=$(user-settings-prompt)
        if whiptail --title "${wt_title}" --yesno "${wt_prompt}" 0 0 3>&1 1>&2 2>&3; then
            break
        fi
    fi
done

if whiptail --title "${wt_title}" --yesno "Do you want to set connection options, such as country or p2p?" 0 0; then
    while :; do
        connect_options_prompt=("Country" "${country}")
        connect_options_prompt+=("Group" "${group}")
        connect_options_prompt+=("Done" "")
        choice=$(whiptail --title "${wt_title}" --menu "Choose an option" 0 50 0 "${connect_options_prompt[@]}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            case $choice in
                Group) choose-group ;;
                Country) choose-country ;;
                Done) break ;;
            esac
        else
            country=""
            group=""
            break
        fi
    done
fi

perform-installation | whiptail --title "${wt_title}" --gauge "Performing operations..." 6 50 0
if whiptail --title "${wt_title}" --yesno "Do you want to set the LAN interface as down when the system boots?" 0 0; then
    [[ -f /etc/rc.local.sh ]] && mv /etc/rc.local.sh /etc/rc.local
    [[ -f /etc/rc.local ]] && cp /etc/rc.local /etc/rc.local.sh
    cat <<EOF > /etc/rc.local
#!/usr/bin/env bash
source /etc/rc.local.sh
/usr/sbin/ip link set ${lan_interface} down
EOF
fi
whiptail --title "${wt_title}" --infobox "Service install is complete.

You can change additional settings by editing

          /root/connect-nord.conf



" 0 50
sleep 1
