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
## constants
true=0
false=1
logfile="./install.log"
wt_title="Router Setup"

## variables
declare -a n_interfaces
declare -A n_interface_pool
declare -a n_interface_prompt
lan_interface=
wan_interface=
lan_address=
dhcp_start=
dhcp_end=
dhcp_lease=
not_nord=$false
declare -a n_settings_query_list
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

## functions
test-ip() {
    if [[ $(ipcalc "$1") =~ (Private) ]]; then
        return $true
    else
        return $false
    fi
}

get-subnet() {
    IFS="." read -ra sn_array <<< "$1"
    sn_prefix="${sn_array[0]}"."${sn_array[1]}"."${sn_array[2]}"
    echo "${sn_prefix}"
}

get-octet() {
    index=
    if [[ -z $2 ]]; then
        index=3
    else
        index=$2
    fi
    IFS="." read -ra oc_array <<< "$1"
    echo "${oc_array[$index]}"
}

get-wan-interface() {
    while :; do
        wt_prompt="Select the WAN interface."
        wan_interface=$(whiptail --title "${wt_title}" --radiolist "${wt_prompt}" 0 50 0 "${n_interface_prompt[@]}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            for (( i=0; i<${#n_interface_prompt[@]}; i+=3 )); do
                if [[ ${n_interface_prompt[$i]} =~ $wan_interface ]]; then
                    if [[ ${n_interface_prompt[$i]} =~ (LAN) ]]; then
                        lan_interface=""
                    fi
                    n_interface_prompt[$((i+1))]="WAN"
                    return
                fi
            done
        else
            exit
        fi
    done
}

get-lan-interface() {
    while :; do
        wt_prompt="Select the LAN interface."
        lan_interface=$(whiptail --title "${wt_title}" --radiolist "${wt_prompt}" 0 50 0 "${n_interface_prompt[@]}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            for (( i=0; i<${#n_interface_prompt[@]}; i+=3 )); do
                if [[ ${n_interface_prompt[$i]} =~ $lan_interface ]]; then
                    if [[ ${n_interface_prompt[$i]} =~ (WAN) ]]; then
                        wan_interface=""
                    fi
                    n_interface_prompt[$((i+1))]="LAN"
                    return
                fi
            done
        else
            exit
        fi
    done
}

get-lan-address() {
    while :; do
        wt_prompt="Enter ipv4 address for LAN.(no cidr)"
        lan_address=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 50 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            if test-ip "$lan_address" ; then
                return
            else
                whiptail --title "${wt_title}" --msgbox "Please enter a valid private ipv4 address" 0 50 3>&1 1>&2 2>&3
            fi
        else
            exit
        fi
    done
}

get-dhcp-start() {
    sn_lan=$(get-subnet "$lan_address")
    while :; do
        wt_prompt="Enter starting dhcp pool ipv4 address."
        dhcp_start=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 50 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            sn_dhcp_start=$(get-subnet "$dhcp_start")
            if [ "$sn_dhcp_start" == "$sn_lan" ] && test-ip "$dhcp_start"; then
                return
            else
                whiptail --title "${wt_title}" --msgbox "Please enter a valid ipv4 address in the same subnet as ${lan_address}" 0 50 3>&1 1>&2 2>&3
            fi
        else
            exit
        fi
    done
}

get-dhcp-end() {
    sn_lan=$(get-subnet "$lan_address")
    while :; do
        wt_prompt="Enter ending dhcp pool ipv4 address."
        dhcp_end=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 50 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            sn_dhcp_end=$(get-subnet "$dhcp_end")
            if [ "$sn_dhcp_end" == "$sn_lan" ] && test-ip "$dhcp_end"; then
                return
            else
                whiptail --title "${wt_title}" --msgbox "Please enter a valid ipv4 address in the same subnet as ${lan_address}" 0 50 3>&1 1>&2 2>&3
            fi
        else
            exit
        fi
    done
}

get-dhcp-lease() {
    while :; do
        wt_prompt="Enter dhcp lease time.
Valid format: 1-999999[h|m|s]"
        dhcp_lease=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 50 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status -eq 0 ]]; then
            if [[ $dhcp_lease =~ ^([1-9][0-9]*[h|m|s])$ ]]; then #first digit [1-9], followed by unlimited [0-9] digits, ends with h, m, or s
                return
            else
                whiptail --title "${wt_title}" --msgbox "Please enter a valid lease time" 0 50 3>&1 1>&2 2>&3
            fi
        else
            exit
        fi
    done
}

user-settings-prompt() {
    cat <<EOF
WAN Interface    : ${wan_interface}
LAN Interface    : ${lan_interface}
LAN ipv4 Address : ${lan_address}
DHCP Pool Start  : ${dhcp_start}
DHCP Pool End    : ${dhcp_end}
DHCP Lease Time  : ${dhcp_lease}

Are these settings correct?

EOF
}

get-files() {
## acquire config files
    files_list=(
#       pct  message                                local filename                 file url
        0   "Getting /etc/netplan/config-wan.yaml" "/etc/netplan/config-wan.yaml" "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-dhcp.yaml"
        5   "" "" "" 10 "" "" "" 15 "" "" ""
        20  "Getting /etc/netplan/config-lan.yaml" "/etc/netplan/config-lan.yaml" "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-static.yaml"
        25  "" "" "" 30 "" "" "" 35 "" "" ""
        40  "Getting /etc/iptables/rules.v4"       "/etc/iptables/rules.v4"       "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/rules.v4"
        45  "" "" "" 50 "" "" "" 55 "" "" ""
        60  "Getting /etc/dnsmasq.conf"            "/etc/dnsmasq.conf"            "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/dnsmasq.conf"
        65  "" "" "" 70 "" "" "" 75 "" "" ""
        80  "Getting /etc/sysctl.conf"             "/etc/sysctl.conf"             "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/sysctl.conf"
        85  "" "" "" 90 "" "" "" 95 "" "" ""
        100 "All files retrieved!"                 ""                             ""
    )
    for ((i=0;i<${#files_list[@]};i+=4)); do
        if [[ -n ${files_list[$((i+1))]} ]]; then
            echo -e "XXX\n${files_list[$i]}\n${files_list[$((i+1))]}\nXXX"
            wget -qO "${files_list[$((i+2))]}" "${files_list[$((i+3))]}"
        else
            echo ${files_list[$i]}
        fi
    done| whiptail --title "$wt_title" --gauge "Fetching configuration files..." 6 60 0
    whiptail --title "${wt_title}" --infobox "Files retrieved!" 7 60
    sleep 1
}

write-files() {
    file_configs=(
#       pct  message                                             pattern         replacement      file
        0   "Writing /etc/netplan/config-lan.yaml"              "net_interface" "$lan_interface" "/etc/netplan/config-lan.yaml"
        12  ""                                                  "ip_address"    "$lan_address"   "/etc/netplan/config-lan.yaml"
        25  "Writing /etc/netplan/config-wan.yaml"              "net_interface" "$wan_interface" "/etc/netplan/config-wan.yaml"
        37  "Writing /etc/iptables/rules.v4"                    "lan_interface" "$lan_interface" "/etc/iptables/rules.v4"
        41  ""                                                  "nordlynx"      "$wan_interface" "/etc/iptables/rules.v4"
        42  "The answer to life, the universe, and everything!" ""              ""               ""
        43  "Writing /etc/iptables/rules.v4"                    ""              ""               ""
        50  "Writing /etc/dnsmasq.conf"                         "lan_interface" "$lan_interface" "/etc/dnsmasq.conf"
        62  ""                                                  "dhcp_start"    "$dhcp_start"    "/etc/dnsmasq.conf"
        75  ""                                                  "dhcp_end"      "$dhcp_end"      "/etc/dnsmasq.conf"
        88  ""                                                  "dhcp_lease"    "$dhcp_lease"    "/etc/dnsmasq.conf"
        100 "Done writing files!"                               "" "" ""
    )
    for ((i=0;i<${#file_configs[@]};i+=5)); do
        percent=${file_configs[$i]}
        message=${file_configs[$((i+1))]}
        pattern=${file_configs[$((i+2))]}
        replace=${file_configs[$((i+3))]}
        filename=${file_configs[$((i+4))]}
        sleep .1
        if [[ -n $message ]]; then
            echo -e "XXX\n${percent}\n${message}\nXXX"
        else
            echo $percent
        fi
        if [[ -n $pattern && -n $replace ]]; then
            if [[ $pattern =~ (nordlynx) && $not_nord == $false ]]; then
                : # skip this substitution
            else
                sed -i "s/$pattern/$replace/g" $filename
            fi
        fi
    done| whiptail --title "${wt_title}" --gauge "Writing files..." 6 60 0
    whiptail --title "${wt_title}" --infobox "Files have been written" 7 60
    sleep 1
}

restart-services() {
    update-gauge 0 "Restarting service: iptables"
    systemctl restart iptables >> ${logfile} 2>&1
    update-gauge 33 "Restarting service: dnsmasq"
    systemctl restart dnsmasq >> ${logfile} 2>&1
    update-gauge 67 "Applying netplan settings"
    netplan apply >> ${logfile} 2>&1
    update-gauge 100 "Services restarted!"
    sleep 1
}

update-gauge() {
    echo -e "XXX\n${1}\n${2}\nXXX"
}
populate-settings-query() {
        while IFS=":" read -r key value ; do
                onoff=
                if [[ $value =~ (enabled) ]]; then
                        onoff="on"
                elif [[ $value =~ (disabled) ]]; then
                        onoff="off"
                fi
                if [[ ${!n_settings_actions_template[*]} =~ ($key) ]]; then
                        n_settings_query_list+=("${key}" "${value}" "${onoff}")
                fi
        done < <(nordvpn settings)
}
get-nord-settings() {
    wt_prompt="
Please choose which settings to enable.

All unselected settings will be disabled"
    mapfile -t nord_settings < <(whiptail --title "${wt_title}" --checklist "${wt_prompt}" 0 0 0 --separate-output --nocancel "${n_settings_query_list[@]}" 3>&1 1>&2 2>&3)
    for setting in "${nord_settings[@]}"; do
        n_settings_actor["${n_settings_actions_template[${setting}]}"]="on"
    done
}
apply-nord-settings() {
    for setting in "${!n_settings_actor[@]}"; do
        nordvpn set "${setting}" "${n_settings_actor[${setting}]}"
    done
}
perform-nord-installation() {
    {
        echo -e "XXX\n0\nDownloading and running NordVPN install script...\nXXX"
        bash < <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh) -s -- -n &
        job_pid=$!
        # in reality this usually takes longer than the timed steps here. These steps are just for eye candy
        echo 10
        sleep .5
        echo 20
        sleep .5
        echo 30
        sleep .5
        echo 40
        sleep .5
        echo 50
        sleep .5
        echo 60
        sleep .5
        echo 70
        sleep .5
        echo 80
        sleep .5
        echo 90
        while ps -p $job_pid &> /dev/null; do
            # hang out here until the install script is done
            sleep .5
        done
        wait $job_pid
        if [[ $? == 0 ]]; then
            echo -e "XXX\n100\nNordVPN installed\nXXX"
            sleep .5
        fi
        if ! which nordvpn; then
            return $false
        else
            return $true
        fi
    }| whiptail --title "${wt_title}" --gauge "Installing NordVPN" 0 60 0
}
login-nord() {
    n_login_url=
    while :; do
        read -ra n_redirect_url < <(nordvpn login)
        if [[ ${n_redirect_url[*]} =~ (You are already logged in) ]]; then
            echo -e "\e[1;32mYou are already logged in.\e[0m"
            whiptail --title "${wt_title}" --infobox "You are already logged in." 0 0
        fi
        if [[ ${n_redirect_url[-1]} =~ (login-redirect) ]]; then
            n_login_url="${n_redirect_url[-1]}"
            break
        fi
        sleep 2
    done
    wt_title="NordVPN Login"
    wt_prompt="1 - Copy this link and paste it in your browser:

        ${n_login_url}

2 - Cancel any request to open a new window.
3 - Right-click on the 'Continue' button and copy the link.
4 - Paste the link here:"

    n_callback_url=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 0 3>&1 1>&2 2>&3)

    if nordvpn login --callback "$n_callback_url"; then
        return $true
    else
        return $false
    fi
}
### display license
whiptail --title "${wt_title}" --infobox "${license}" 0 0
sleep 1

### consent to proceed
wt_prompt="This will setup this system as a router, wither simple or for NordVPN. The installation
process will install the following packages: iptables-persistent dnsmasq dnsmasq-utils netplan.io

This will also install ipcalc if not already installed

Do you wish to proceed?"
if ! whiptail --title "${wt_title}" --yesno "${wt_prompt}" 0 0 0 3>&1 1>&2 2>&3; then
    exit
fi

### install packages
clear
if apt update && apt upgrade -y;then
    if ! apt install iptables-persistent netplan.io dnsmasq dnsmasq-utils -y; then
        whiptail --title "${wt_title}" --msgbox "Error installing packages. Check your
configuration and try again." 0 0
        exit
    fi
    if ! which ipcalc; then
        if ! apt install ipcalc -y; then
            whiptail --title "${wt_title}" --msgbox "Error installing ipcalc. Check your
configuration and try again." 0 0
        exit
        fi
    fi
else
    whiptail --title "${wt_title}" --msgbox "Error installing packages. Check your
configuration and try again." 0 0
    exit
fi

### populate network interfaces
sys_interfaces=$(ls /sys/class/net)
for interface in $sys_interfaces; do
        if [[ $interface =~ ^([e][no|th|np|ns|th]) ]]; then
                n_interfaces+=("$interface")
                n_interface_pool["$interface"]="."
        fi
done

### validate interface count
if [[ ${#n_interfaces[@]} -lt 2 ]]; then
    wt_prompt="Not enough network interfaces.
Check your setup and try again."
    whiptail --title "${wt_title}" --msgbox "${wt_prompt}" 0 0 3>&1 1>&2 2>&3
    exit
else

    for i in "${!n_interface_pool[@]}"; do
        n_interface_prompt+=("$i" "${n_interface_pool[$i]}" OFF)
    done
fi
### get user input
router_type=$(whiptail --title "${wt_title}" --menu "Select which type of router you wish to setup" 0 0 0 "nord" "NordVPN router. Will route WAN traffic over NordVPN's nordlynx interface" "basic" "Basic router. Will route traffic over the WAN interface." 3>&1 1>&2 2>&3)
exitstatus=$?
if [[ $exitstatus -ne 0 ]]; then
    exit
fi
if [[ $router_type =~ (basic) ]]; then
    not_nord=$true
    echo "Setting up as a basic router" >> $logfile
    whiptail --title "${wt_title}" --infobox "Setting up as a basic router


" 0 0
    sleep 2
elif [[ $router_type =~ (nord) ]]; then
    not_nord=$false
    echo "Setting up as a NordVPN router" >> $logfile
    whiptail --title "${wt_title}" --infobox "Setting up as a NordVPN router


" 0 0
    sleep 2
fi
while :; do
    while :; do # interface assignments
        get-wan-interface
        if [[ -n $lan_interface && -n $wan_interface && $wan_interface != $lan_interface ]]; then
            break
        fi
        get-lan-interface
        if [[ -n $lan_interface && -n $wan_interface && $wan_interface != $lan_interface ]]; then
            break
        fi
    done # interface assignment
    while :; do # address and dhcp lease assignment
        get-lan-address
        get-dhcp-start
        get-dhcp-end
        get-dhcp-lease
        break
    done # address and dhcp lease assignment
    wt_prompt=$(user-settings-prompt)
    if whiptail --title "${wt_title}" --yesno "${wt_prompt}" 0 0 3>&1 1>&2 2>&3; then
        break
    fi
done
get-files
write-files
if [[ $not_nord == $false ]]; then
    if ! perform-nord-installation; then
        whiptail --title "${wt_title}" --msgbox "There was a problem installing the NordVPN application." 0 0
        exit
    fi
    populate-settings-query
    if [[ $not_nord == $false ]]; then
        get-nord-settings
    fi
    apply-nord-settings
    if ! login-nord; then
        whiptail --title "${wt_title}" --msgbox "There was a problem logging in.
Please try again from the command line." 0 0
    fi
fi
restart-services | whiptail --title "${wt_title}" --gauge "Restarting services..." 6 50 0
whiptail --title "${wt_title}" --infobox "Router setup complete.

It is recommended to reboot at this time.


" 0 50
sleep 1
exit
