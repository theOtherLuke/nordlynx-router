#!/usr/bin/env bash
clear

#set -x
### COLORS
CL='\e[0m' #
BK='\e[0;30m'
RD='\e[0;31m' #
GN='\e[0;32m' #
YL='\e[0;33m' #
BU='\e[0;34m'
PP='\e[0;35m' #
CY='\e[0;36m' #
WT='\e[0;37m'
LTBK='\e[1;30m' # gray?
LTRD='\e[1;31m'
LTGN='\e[1;32m' #
LTYL='\e[1;33m' #
LTBU='\e[1;34m'
LTPP='\e[1;35m'
LTCY='\e[1;36m'
LTWT='\e[1;37m'

declare -a interfaces
declare -a other_ifaces

# associative array > aka- key-value array --- ["key"]="value"
declare -A nord_settings=(
        ["tpl"]="on"
        ["analytics"]="off"
        ["autoconnect"]="off"
        ["killswitch"]="on"
        ["post-quantum"]="on"
        ["P2P"]="off"
)

# array we will use to set settings
# routing and lan-discovery are required
# the other settings will be appended later
nord_settings_actor=(
        "routing on"
        "lan-discovery on"
        "virtual-location off"
)

# array for comparison
nord_settings_list=(
        "tpl"
        "analytics"
        "autoconnect"
        "killswitch"
        "post-quantum"
        "P2P"
)

true=0
false=1
lan_interface=
wan_interface=
dhcp_start=
dhcp_end=
dhcp_lease=
lan_subnet=
lan_address=
mgmt_interface=
mgmt_address=
iptables_file=
wired_interfaces=0
wireless_interfaces=0
reply=
spinner_pid=
row=
s_row=
success_mark="${LTGN}✔${CL}"
failed_mark="${LTRD}✘${CL}"
unknown_mark="${LTYL}?${CL}"

license(){
        echo -e "$LTGN"
        cat <<EOF
MIT License

Copyright (c) 2024 nodaddyno

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
        echo -e "$CL"
}

header(){
        cat <<EOF
            _   _               ___     ______  _   _
           | \ | | ___  _ __ __| \ \   / /  _ \| \ | |
           |  \| |/ _ \| '__/ _  |\ \ / /| |_) |  \| |
           | |\  | (_) | | | (_| | \ V / |  __/| |\  |
           |_| \_|\___/|_|  \__,_| _\_/  |_|   |_| \_|
                 |  _ \ ___  _   _| |_ ___ _ __
                 | |_) / _ \| | | | __/ _ \ '__|
                 |  _ < (_) | |_| | ||  __/ |
                 |_| \_\___/ \__,_|\__\___|_|

        Whole-network VPN router using the NordVPN Service
EOF
        IFS=";[" read -rsdR -p $'\E[6n' e r c
        row=$r
        s_row=$r
}

cleanup() {
        set +x
        echo -e '\e['$((row+2))'H\e[?25h\e[0m'
        if ps -p $spinner_pid &> /dev/null ; then
                kill "$spinner_pid" &> /dev/null
        fi
}

trap cleanup EXIT

# check what distro
release=$(cat /etc/*-release | grep NAME)
release=${release,,}

if [[ ! "$release" =~ (ubuntu|debian) ]]; then
        read -rsn1 -p "Only Debian and Ubuntu are currently supported by this script. You may try installing this manually by following the writeup. Press any key to exit..."
fi

echo -ne '\e[?25l' # hide the cursor
clear && license && sleep 5

# check if we have internet
if [[ ! $1 =~ (-i) ]] ; then
        test="google.com"
        echo "Verifying active internet connection..."
        for (( i = 0; i < 10; i++ )) ; do # give network time to come back up
                echo -ne "\e[7GChecking for connection..."
                if nc -zw1 $test 443 &> /dev/null && echo |openssl s_client -connect $test:443 2>&1 |awk '
                        $1 == "SSL" && $2 == "handshake" { handshake = 1 }
                        handshake && $1 == "Verification:" { ok = $2; exit }
                        END { exit ok != "OK" }' &> /dev/null ; then
                        break
                fi
                if [[ $i -eq 5 ]] ; then
			clear
			header
                        echo "Active internet connection required for this installation. Connect to the internet and try again."
                        echo "If you are sure this is incorrect, you can try running with the '-i' option"
                        exit 87
                fi
                sleep $i
        done
fi

clear && header && sleep 1

sed -i 's/deb cdrom/#deb cdrom/' /etc/apt/sources.list

spinner() {
        spinner=( '-' '\\' '|' '/' )
        while :; do
                for (( i = 0; i < 4; i++ )) ; do
                        s="${spinner[$i]}"
                        echo -ne "$GN\e[""$row""H\e[5G$s $CL"
                        sleep .2
                done
        done
}

show-spinner() {
        if [[ ! "$spinner_pid" == "" ]] ; then
                kill "$spinner_pid" &> /dev/null
        fi
        spinner & spinner_pid=$! # send to background process and get pid
}

# usage:
# kill-spinner <status>
#
#  status - 0 = success
#           1 = failure
#           2 = failure with custom message
#           3 = unknown status, non-exiting
#           4 = failure, non-exiting
kill-spinner() {
        if ps -p $spinner_pid &> /dev/null ; then
                kill "$spinner_pid" &> /dev/null
        fi
        case $1 in
                0)
                        echo -ne "\e[""$row""H\e[5G$success_mark"
                        return
                        ;;
                1)
                        echo -ne "\e[""$row""H\e[5G$failed_mark"
                        echo -ne "\e[""$row""H\e[7G\e[JInstall failed! Exiting..."
                        exit 1
                        ;;
                2)
                        echo -ne "\e[""$row""H\e[5G$failed_mark"
                        exit 1
                        ;;
                3)
                        echo -ne "\e[""$row""H\e[5G$unknown_mark"
                        return
                        ;;
                4)
                        echo -ne "\e[""$row""H\e[5G$failed_mark"
                        ;;
        esac
        echo -ne "\e[""$row""H\e[5G "
}

yes-no() {
        default="y"
        show_default="[Y|n]"
        if [[ "$2" =~ ^([y|Y|n|N])$ ]]; then
                default=$2
                case $default in
                        [Yy]) show_default="[Y|n]" ;;
                        [Nn]) show_default="[y|N]" ;;
                esac
        fi
        while :; do
                read -rsn1 -p $'\e[1;33m'"$1 $show_default "$'\e[0m' yn && echo -ne '\e[M'
                if [[ $yn == "" ]]; then
                        yn=$default
                fi
                case $yn in
                        [Yy]) return 0 ;;
                        [Nn]) return 1 ;;
                esac
        done
}

mgmt_address-show() {
        if [ -z "$mgmt_address" ] && [ ! "$mgmt_dhcp" ] ; then
                echo ""
        else
                echo -e "$PP""Management Address :$YL   $mgmt_address$CL"
        fi
}

show-select-interface() {
        echo
        for (( i = 0; i < ${#interfaces[@]}; i++ )) ; do
                echo -e "\e[15G$PP$i :$YL\e[20G${interfaces[$i]}$CL"
        done
}

show-select-mgmt-interface() {
        echo
        for (( i = 0; i < ${#other_ifaces[@]}; i++ )) ; do
                echo -e "\e[15G$PP$i :$YL\e[20G${other_ifaces[$i]}$CL"
        done
}

test-ip() {
        if [[ $(ipcalc "$1") =~ (Private) ]] ; then
                return $true
        else
                return $false
        fi
}

get-subnet() {
        IFS="." read -ra sn_array <<< "$1"
        subnet_prefix="${sn_array[0]}"."${sn_array[1]}"."${sn_array[2]}"
        echo "$subnet_prefix"
        return 1
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
        return "${oc_array[$index]}"
}


nord-settings-prompt() {
        echo -e "$GN\n  (tpl = Threat Protection Lite)"
        for (( i = 0; i < ${#nord_settings_list[@]}; i++ )) ; do
                setting="${nord_settings_list[$i]}"
                echo -e "\e[10G$LTCY$i >$CL $setting\e[30G:$LTYL ${nord_settings["$setting"]}"
        done
        echo -e "\n\e[10G$LTCY""A >""$CL Accept Settings\n"
        echo -e "\e[10G$CL""routing""\e[30G:$LTYL on$RD (required)"
        echo -e "\e[10G$CL""lan-discovery""\e[30G:$LTYL on$RD (required)"
        echo -ne "$CL"
}

prompt-login-callback-msg() {
        url=$1
        echo -e "$CY""\e[10G1 - Copy this link and paste it in your browser.\n"
        echo -e "$LTBU""\e[20G$url\n"
        echo -e "$CY""\e[10G2 - Login to your account in the browser."
        echo -e "$CY""\e[10G3 - Cancel any request to open anything"
        echo -e "$CY""\e[10G4 - Right-click the \"CONTINUE\" button and copy the link"
        echo -ne "$CY""\e[10G5 - Paste the link""$LTGN"" here:"
}

# check for ipcalc and install if missing
iptables_file="/etc/iptables/rules.v4"
if ! which ipcalc &> /dev/null ; then
	echo -ne "\e[7G\e[J""Installing ipcalc"
	show-spinner
	if apt install ipcalc -y &> /dev/null ; then
		echo -ne "\e[7G\e[J""ipcalc is installed"
		kill-spinner 0
	else
		kill-spinner 1
	fi
fi

# check if reconfiguring existing setup and disable monitor
if [[ -f /etc/systemd/system/nordvpn-net-monitor.service ]] ; then
	systemctl disable --now nordvpn-net-monitor.service
	nordvpn d &> /dev/null
	nordvpn set killswitch off &> /dev/null
fi

# gather network interfaces
echo -ne "\e[""$row""H\e[7GGetting available network interfaces"
show-spinner
while :; do
        # Populate list of physical network interfaces
        system_interfaces=$(ls /sys/class/net) &> /dev/null
        for interface in $system_interfaces; do
                if [[ $interface =~ ^(([e][no|np|ns|th])|([w][lp|lan|lo])) ]]; then
                        interfaces+=("$interface")
                        if [[ $interface =~ ^(([e][no|np|ns|th])) ]]; then
                                ((wired_interfaces++))
                        elif [[ $interface =~ ^(([w][lp|lan|lo])) ]]; then
                                ((wireless_interfaces++))
                        fi
                fi
        done
        if [ ${#interfaces[@]} -lt 2 ] && [ ${#interfaces[@]} == $wired_interfaces ]; then
                echo -ne "\e[""$row""H\e[7GNot enough interfaces. Please try again with at least 2 interfaces."
                kill-spinner 2
        elif [ ${#interfaces[@]} -lt 2 ] && [ ${#interfaces[@]} -gt $wired_interfaces ] && [ $wireless_interfaces -ge 1 ]; then
                kill-spinner 0
                if yes-no "There is only 1 wired interface, but it appears there is a wireless interface. Do you still want to proceed?" ; then
                        break
                else
                        echo -ne "\e[7G""User cancelled installation"
                        exit 2
                fi
        else # we have enough interfaces
                echo -ne "\e[7G\e[K""${#interfaces[@]} network interfaces found"
                kill-spinner 0
                break
        fi
done

sleep 2

########################################################################
##########                   GET USER INPUT                   ##########
########################################################################

while :; do
        # network interface assignment
        while :; do
                # WAN Interface
                echo -e "\e[""$row""H\e[5G$unknown_mark\e[7G\e[J""WAN Interface"
                while :; do
                        echo -ne "\e["$((row+1))"H\e[J"
                        show-select-interface "WAN"
                        while :; do # loop until legitimate selection is made
                                read -rsn1 -p $'\e[7G'"Select WAN interface : " choice && echo -ne "\e[M"
                                if [[ "$choice" -ge 0 ]] && [[ "$choice" -lt "${#interfaces[@]}" ]] ; then
                                        wan_interface="${interfaces[$choice]}"
                                        echo
                                        break
                                fi
                        done
                        if [ ! -z "$wan_interface" ]; then
                                ### wireless wan
                                if [[ $wan_interface =~ ^([w][lp|lan|lo]) ]]; then
                                show-spinner
                                echo -ne "\e[""$((row))""H\e[7G\e[JRetrieving current WiFi credentials for $wan_interface"
                                ### interfaces method
                                if [[ -f /etc/network/interfaces ]] && grep wpa-ssid < /etc/network/interfaces &> /dev/null ; then
                                        while IFS=" " read -ra line ; do
                                                if [[ ${line[*]} =~ (ssid) ]] ; then
                                                        ssid="${line[-1]}"
                                                elif [[ ${line[*]} =~ (psk) ]] ; then
                                                        psk="${line[-1]}"
                                                fi
                                        done < /etc/network/interfaces
                                ### netplan method
                                elif which netplan &> /dev/null && [[ -d "/etc/netplan/" ]] ; then
                                        for file in /etc/netplan/*.yaml ; do
                                                if grep -i wifis < "$file" &> /dev/null ; then
                                                        is_ssid=0
                                                        while read -r line ; do
                                                                if [[ $is_ssid == 1 ]] ; then
                                                                        ssid="${line%%:*}"
                                                                        is_ssid=0
                                                                elif [[ "$line" =~ "access-points" ]] ; then
                                                                        is_ssid=1
                                                                elif [[ "$line" =~ "password" ]] ; then
                                                                        pass_temp=( "$line" )
                                                                        psk="${pass_temp[1]}"
                                                                fi
                                                        done < "$file"
                                                        break
                                                fi
                                        done
                                elif which NetworkManager &> /dev/null && [[ -d "/etc/NetworkManager/system-connections/" ]] ; then
                                        for file in /etc/NetworkManager/system-connections/*.nmconnection ; do
                                                if grep -i wifi < "$file" &> /dev/null ; then
                                                        while read -r line ; do
                                                                if [[ "$line" =~ "ssid" ]] ; then
									ssid="${line#*=}"
                                                                elif [[ "$line" =~ "psk" ]] ; then
									psk="${line#*=}"
                                                                fi
                                                        done < "$file"
                                                        break
                                                fi
                                        done
                                fi
                                sleep 1
                                if [[ $ssid != "" ]] && [[ $psk != "" ]] ; then
                                        echo -ne "\e[7G\e[J""WiFi credentials retrieved"
                                        sleep 1
                                else
                                        echo -ne "\e[7G\e[J""Failed to retrieve WiFi credentials!"
                                        kill-spinner 1
                                fi
                        fi
                        if [[ $wan_interface =~ ^([w][lp|lan|lo]) ]] ; then
                                echo -e "\e[""$row""H\e[7G\e[J""WAN interface           : $wan_interface   SSID :  $ssid"
                        else
                                echo -e "\e[""$row""H\e[7G\e[J""WAN interface           : $wan_interface"
                        fi
                        kill-spinner 0
                        ((row++))
                        break
                fi
        done # WAN Interface
        # LAN Interface
        echo -ne "\e[""$row""H\e[5G$unknown_mark\e[7G\e[J""Select LAN Interface"
        echo
        while :; do
                echo -ne "\e["$((row+1))"H\e[J"
                show-select-interface "LAN"
                while :; do
                        read -rsn1 -p $'\e[7G'"Select LAN interface : " choice && echo -ne "\e[M"
                        if [[ "$choice" -ge 0 ]] && [[ "$choice" -lt "${#interfaces[@]}" ]] ; then
                                if [[ "${interfaces[$choice]}" =~ ^([w][lp|lan|lo]) ]]; then
                                        read -rsn1 -p "Wireless LAN is not yet implemented in this script. Please\nchoose a different LAN interface. Press any key to continue..."
                                        break
                                elif [[ "${interfaces[$choice]}" == "$wan_interface" ]] ; then
                                        read -rsn1 -p "Please select different interfaces for LAN and WAN. Press any key to continue..."
                                        break
                                else
                                        lan_interface="${interfaces[$choice]}"
                                        echo
                                        break
                                fi
                        fi
                done
                if [ ! -z "$lan_interface" ]; then
                        echo -ne "\e[""$row""H\e[5G$success_mark\e[7G\e[JLAN interface           : $lan_interface"
                        echo
                        ((row++))
                        break
                fi
        done # LAN interface

        # Management Interface
        echo -ne "\e[""$row""H\e[J"
        for iface in "${interfaces[@]}" ; do
                if [[ "$iface" != "$wan_interface" ]] && [[ "$iface" != "$lan_interface" ]] ; then
                        other_ifaces+=( "$iface" )
                fi
        done
        if [[ ! ${other_ifaces[*]} =~ (NONE) ]] ; then
                other_ifaces+=( "NONE" )
        fi
        if [[ ${#other_ifaces[@]} -gt 1 ]] ; then
                echo -ne "\e[""$row""H\e[5G$unknown_mark\e[7G\e[JSelect management Interface (if other than LAN)"
                while :; do
                        if [[ ${#other_ifaces[@]} -lt 1 ]] ; then
                                break
                        fi
                        echo -ne "\e["$((row+1))"H\e[J"
                        show-select-mgmt-interface "LAN"
                        while :; do
                                read -rsn1 -p $'\e[7G'"Select management interface : " choice && echo -ne "\e[M"
                                if [[ "$choice" -ge 0 ]] && [[ "$choice" -lt "${#other_ifaces[@]}" ]] ; then
                                        mgmt_interface="${other_ifaces[$choice]}"
                                        echo -e "\e[""$row""H\e[7G\e[JManagement interface    : $mgmt_interface"
                                        kill-spinner 0
                                        ((row++))
                                        break
                                fi
                        done
                        if [ -z "$mgmt_interface" ] ; then
                                mgmt_interface="NONE"
                                echo -e "\e[""$row""H\e[7G\e[JManagement interface    : $mgmt_interface"
                                kill-spinner 0
                                ((row++))
                                break
                        fi
                        break
                done
        else
                mgmt_interface="NONE"
                echo -ne "\e[""$row""H\e[7G\e[J""Management interface    : $mgmt_interface"
                kill-spinner 0
                ((row++))
        fi
        accepted=
        while echo -ne "\e["$((row+2))"H\e[7G\e[J" ; do
                read -rsn1 -p $'\e[7G'"Accept network interface settings?" reply
                case "$reply" in
                        [Yy])
                                echo -ne "\e[""$row""H\e[5G\e[J$success_mark Settings accepted"
                                accepted=$true
                                break
                                ;; #continue
                        [Nn])
                                accepted=$false
                                row=$s_row
                                other_ifaces=()
                                break
                                ;; #try again
                esac
        done
        if [[ "$accepted" == "$true" ]] ; then
                break
        fi
        sleep 1
        done # network interface assignment

        # ipv4 address and dhcp settings
        while :; do
                s_row=$row
                # get lan address
                echo -ne "\e[""$row""H\e[5G$unknown_mark\e[7G\e[JLAN ipv4 address"
                while :; do
                        echo -ne "\e["$((row+2))"H\e[J"
                        read -r -p $'\e[7G'"Enter LAN ipv4 address : " lan_ip
                        if test-ip "$lan_ip" ; then
                                echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[J""LAN ipv4 address        : $lan_ip"
                                ((row++))
                                break
                        else
                                echo -ne "\e[7G\e[J""Please enter a valid private ipv4 address"
                                sleep 2
                        fi
                done # get lan address
                lan_subnet=$(get-subnet "$lan_ip")
                # setup dhcp

                # get dhcp start address
                echo -ne "\e[5G$unknown_mark\e[7G\e[J""DHCP starting address"
                while :; do
                        echo -ne "\e["$((row+2))"H\e[J"
                        read -r -p $'\e[7G'"Enter dhcp range starting address : " dhcp_start
                        if test-ip "$dhcp_start" ; then
                                subn=$(get-subnet "$dhcp_start")
                                if [ "$subn" == "$lan_subnet" ]; then
                                        echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[J""DHCP starting address   : $dhcp_start"
                                        ((row++))
                                        break
                                else
                                        read -rsn1 -p "Please provide a dhcp starting address in the same subnet\nas the LAN address of $lan_address. Press any key..."
                                fi
                        else
                                read -rsn1 -p "Please provide a valid private ipv4 address. Press any key..."
                        fi
                done # get dhcp start address
                # get dhcp end address
                echo -ne "\e[5G$unknown_mark\e[7G\e[JDHCP ending address"
                while :; do
                        echo -ne "\e["$((row+2))"H\e[J"
                        read -r -p $'\e[7G'"Enter dhcp range ending address :" dhcp_end
                        if test-ip "$dhcp_end" ; then
                                subn=$(get-subnet "$dhcp_end")
                                if [ "$subn" == "$lan_subnet" ]; then
                                        if [ ! "$(get-octet "$dhcp_start")" -ge "$(get-octet "$dhcp_end")" ]; then
                                                echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[J""DHCP ending address     : $dhcp_end"
                                                ((row++))
                                                break
                                        else
                                                read -rsn1 -p "Please provide a dhcp ending address that is higher than\nthe dhcp starting address of $dhcp_start. Press any key..."
                                        fi
                                else
                                        read -rsn1 -p "Please provide a dhcp ending address in the same subnet\nas the LAN address of $lan_ip. Press any key..."
                                fi
                        else
                                read -rsn1 -p "Please provide a valid private ipv4 address. Press any key..."
                        fi
                done # get dhcp end address
                # get dhcp lease time
                echo -ne "\e[5G$unknown_mark\e[7G\e[J""DHCP lease time"
                while :; do
                        echo -ne "\e["$((row+2))"H\e[J"
                        read -r -p $'\e[7G'"Enter dhcp lease time (1-99999[s|m|h]) :" dhcp_lease
                        if [[ ! $dhcp_lease =~ ^(0) ]] && [[ $dhcp_lease =~ ^([0-9]{1,5})h|m|s$ ]] ; then
                                echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[J""DHCP lease time         : $dhcp_lease"
                                ((row++))
                                break
                        else
                                read -rsn1 -p "Please provide a valid dhcp lease time : 1-99999[s|h|m]. Press any key..." && echo -ne "\e[M"
                        fi
                done # get dhcp lease time

                # get management address
                if [ "$mgmt_interface" != "NONE" ] ; then
                        echo -ne "\e[5G$unknown_mark\e[7G\e[JManagement ipv4 address"
                        while :; do
                                echo -ne "\e["$((row+2))"H\e[J"
                                read -r -p $'\e[7G'"Management interface address. Leave blank for dhcp :" mgmt_address
                                if [ -z "$mgmt_address" ] ; then
                                        mgmt_dhcp=$true
                                        echo -e "\e[""$row""H\e[7G\e[J""Management ipv4 address by DHCP"
                                        ((row++))
                                        break
                                else
                                        if test-ip "$mgmt_address" ; then
                                                mgmt_dhcp=$false
                                                echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[JManagement ipv4 address : $mgmt_address"
                                                ((row++))
                                                break
                                        fi
                                fi
                                read -rsn1 -p "Invalid ip address! Please enter a valid private ip address"$'\n'"without CIDR, or leave blank for dhcp. Press any key..." && echo -ne "\e[J"
                        done # Management Addreess
                fi
                # confirm network address settings
                accepted=
                while echo -ne "\e["$((row+2))"H\e[7G\e[J" ; do
                        read -rsn1 -p $'\e[7G'"Accept ip address and dhcp settings?" reply
                        case "$reply" in
                                [Yy])
                                        echo -ne "\e[""$row""H\e[5G\e[J$success_mark Settings accepted"
                                        accepted=$true
                                        break
                                        ;; #continue
                                [Nn])
                                        accepted=$false
                                        row=$s_row
                                        break
                                        ;; #try again
                        esac
                done # confirm network address settings
                if [[ "$accepted" == "$true" ]] ; then
                        break
                fi
                sleep 1
        done # network settings
        s_row=$row

        # get nordvpn settings
        echo -ne "\e[5G$unknown_mark\e[7G\e[J""Choose NordVPN settings"
        while :; do
                echo -ne "\e["$((row+1))"H\e[7G\e[J"
                read -rsn1 -p $'\e[7G'"$(nord-settings-prompt)"$'\n\e[12G'"Select settings: " set_n
                if [[ $set_n =~ ([Aa]) ]] ; then # accept settings
                        for setting in "${nord_settings_list[@]}" ; do
				if [ "$setting" != "P2P" ] ; then
					nord_settings_actor+=("$setting ${nord_settings["$setting"]}")
				fi
                        done
                        echo -e "\e[""$row""H\e[5G$success_mark\e[7G\e[J""NordVPN settings selected"
                        ((row++))
                        break
                elif [[ $set_n =~ ([0-9]) ]] && [[ $set_n < ${#nord_settings[@]} ]] ; then
                        # toggle settings on/off when selected
                        case "${nord_settings[${nord_settings_list[$set_n]}]}" in
                                on) nord_settings["${nord_settings_list[$set_n]}"]="off" ;; #turn off
                                off) nord_settings["${nord_settings_list[$set_n]}"]="on" ;; #turn on
                        esac
                fi
        done # get nordvpn settings
        for (( i = 0; i < ${#nord_settings[@]}; i++ )) ; do
                echo -e "$YL\e[10G*$CL\e[12G${nord_settings_list[$i]}\e[25G: ${nord_settings[${nord_settings_list[$i]}]}"
        done
        echo -e "\e[5G\e[J$success_mark\e[7GSettings complete"
        sleep 1
        break
done # query user for settings


########################################################################
##########                PERFORM INSTALLATION                ##########
########################################################################

for file in /etc/netplan/*.yaml ; do
        mv "$file" "$file".bak &> /dev/null
done

# install packages, download configs
echo -ne "\e[""$row""H\e[7G\e[JUpdating system.$LTGN Please be patient.$CL"
show-spinner
if apt update &> /dev/null && apt upgrade -y &>/dev/null ; then
	echo -e "\e[7G\e[JSystem updated"
	kill-spinner 0
	((row++))
else
	kill-spinner 4
	exit 20
fi
echo -ne "\e[""$row""H\e[7G\e[JInstalling required packages"
show-spinner
if ! dpkg -s iptables-persistent &> /dev/null ; then
        {
                while ! pidof whiptail &> /dev/null ; do sleep 1 ; done # wait to see whiptail show up as a process
                whip_pid=$(pidof whiptail)
                echo -ne "$LTCY\e[""$((row+2))""H\e[15GThis is a work-around for iptables-persistent installer, which\n\e[15Guses whiptail to require user input.\n\e[15GThe files it asks to keep will be overwitten by this install script anyway.$CL"
                echo -ne "\e[""$((row+6))""H\e[15GPress [enter]..."
                while ps -p "$whip_pid" > /dev/null ; do sleep 1 ; done # wait for the first whiptail to close
                while ! pidof whiptail &> /dev/null ; do sleep 1 ; done # wait to see 2nd whiptail show up as a process
                echo -ne "\e[""$((row+6))""H\e[15GPress [enter]$LTRD again...$CL"
        } &
        if ! apt install iptables-persistent -y &> /dev/null ; then # this will sit and wait until both whiptail dialogs are closed
                kill-spinner 4
                exit 21
        fi
        echo -ne "\e[""$((row+2))""H\e[J"
fi
if apt install dnsmasq dnsmasq-utils netplan.io openvswitch-switch -y &> /dev/null ; then # openvswitch isn't strictly needed. only here to silence netplan error message that doesn't affect what we're doing
	echo -ne "\e[7G\e[JRemoving systemd-resolved"
	apt purge systemd-resolved -y &> /dev/null
	echo -e "\e[7G\e[JPackages installed"
	kill-spinner 0
	((row++))
else
	kill-spinner 4
	exit 22
fi # install packages

# download base config files
echo -ne "\e[""$row""H\e[7G\e[JDownloading base config files"
show-spinner
if wget -qO /etc/iptables/rules.v4 https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/rules.v4 ; then
	rm /etc/iptables/rules.v6 &> /dev/null
	if wget -qO /etc/netplan/config-lan.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-static.yaml ; then
		if [[ $wan_interface =~ ^([w][lp|lan|lo]) ]] ; then
			if ! wget -qO /etc/netplan/config-wifi.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-wifi.yaml ; then
				kill-spinner 4
				exit 23
			fi
		else
			if ! wget -qO /etc/netplan/config-wan.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-dhcp.yaml ; then
				kill-spinner 4
				exit 23
			fi
		fi
		if [ "$mgmt_interface" != "NONE" ] ; then
			if [[ "$mgmt_dhcp" == "$true" ]] ; then
				if ! wget -qO /etc/netplan/config-mgmt.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-dhcp.yaml ; then
					kill-spinner 4
					exit 24
				fi
			else
				if ! wget -qO /etc/netplan/config-mgmt.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-static.yaml ; then
					kill-spinner 4
					exit 24
				fi
			fi
		fi
		if wget -qO /etc/dnsmasq.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/dnsmasq.conf ; then
			if wget -qO /etc/sysctl.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/sysctl.conf ; then
				if wget -qO /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/nordvpn-net-monitor.service ; then
					if wget -qO /root/check-connection.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/check-connection.sh ; then
						echo -e "\e[7G\e[JConfig files downloaded"
						kill-spinner 0
						((row++))
					else
						kill-spinner 4
						exit 25
					fi
				else
					kill-spinner 4
					exit 26
				fi
			else
				kill-spinner 4
				exit 27
			fi
		else
			kill-spinner 4
			exit 28
		fi
	else
		kill-spinner 4
		exit 29
	fi
else
	kill-spinner 4
	exit 30
fi # download base config files

# write config files
echo -ne "\e[""$row""H\e[7G\e[JWriting settings to config files"
set_row=$((row+1))
show-spinner
# LAN Interface
sed -i "s/net_interface/$lan_interface/g" /etc/netplan/config-lan.yaml
sed -i "s/ip_address/$lan_ip/g" /etc/netplan/config-lan.yaml
echo -e "\e[""$set_row""H\e[10G$YL*\e[12G$CL/etc/netplan/config-lan.yaml"
sleep .5
((set_row++))
# WAN Interface
if [[ $wan_interface =~ ^([w][lp|lan|lo]) ]]; then
        sed -i "s/wifi_interface/$wan_interface/g" /etc/netplan/config-wifi.yaml
        sed -i "s/wifi_ap/$ssid/g" /etc/netplan/config-wifi.yaml
        sed -i "s/wifi_password/$psk/g" /etc/netplan/config-wifi.yaml
        echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL/etc/netplan/config-wifi.yaml"
	sleep .5
        ((set_row++))
elif [[ $wan_interface =~ ^([e][no|np|ns|th]) ]]; then
        sed -i "s/net_interface/$wan_interface/g" /etc/netplan/config-wan.yaml
        echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL/etc/netplan/config-wan.yaml"
	sleep .5
        ((set_row++))
fi

# Management Interface
if [ "$mgmt_interface" != "NONE" ] ; then
        if [[ "$mgmt_dhcp" == "$true" ]] ; then
                sed -i "s/net_interface/$mgmt_interface/g" /etc/netplan/config-mgmt.yaml
        else
                sed -i "s/net_interface/$mgmt_interface/g" /etc/netplan/config-mgmt.yaml
                sed -i "s/ip_address/$mgmt_address/g" /etc/netplan/config-mgmt.yaml
                echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL/etc/netplan/config-mgmt.yaml"
		sleep .5
		((set_row++))
        fi
	# Write management interface settings to iptables rules file
        sed -i "s/mgmt_interface/$mgmt_interface/g" $iptables_file
        sed -i "s/mgmt_subnet/$(get-subnet "$mgmt_address")/g" $iptables_file
else
        sed -i 's/^.*mgmt.*//g' $iptables_file # remove management interface lines from rules file
fi

sed -i "s/lan_interface/$lan_interface/g" $iptables_file
echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL$iptables_file"
sleep .5
((set_row++))
# backup existing notwork config files
mv /etc/netplan/*.yaml /etc/netplan/*.yaml.bak &> /dev/null
mv /etc/network/interfaces /etc/network/interfaces.bak &> /dev/null
mv /etc/NetworkManager/system-connections/*.nmconnection /etc/NetworkManager/system-connections/*.nmconnection.bak &> /dev/null

# Write dnsmasq config file
sed -i "s/lan_interface/$lan_interface/g" /etc/dnsmasq.conf
sed -i "s/dhcp_start/$dhcp_start/g" /etc/dnsmasq.conf
sed -i "s/dhcp_end/$dhcp_end/g" /etc/dnsmasq.conf
sed -i "s/dhcp_lease/$dhcp_lease/g" /etc/dnsmasq.conf
echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL/etc/dnsmasq.conf"
sleep .5
((set_row++))

# configure interface and post-quantum in check-connection.sh for the monitor service
sed -i "s/wan_iface/$wan_interface/g" /root/check-connection.sh
case "${nord_settings["post-quantum"]}" in # this is part of a work-around for initial connectivity problems on certain systems
	on)
		sed -i "s/post_quantum=$false/post_quantum=$true/g" /root/check-connection.sh
		;;
	off)
		sed -i "s/post_quantum=$true/post_quantum=$false/g" /root/check-connection.sh
		;;
esac
case "${nord_settings["P2P"]}" in
	on)
		sed -i "s/p2p=$false/p2p=$true/g" /root/check-connection.sh
                sed -i 's/country=pref_country/country="p2p"/g' /root/check-connection.sh
		;;
	off)
		sed -i "s/p2p=$true/p2p=$false/g" /root/check-connection.sh
                sed -i 's/country=pref_country/country=/g' /root/check-connection.sh
		;;
esac
chmod +x /root/check-connection.sh &> /dev/null
echo -ne "\e[""$set_row""H\e[10G$YL*\e[12G$CL/root/check-connection.sh"
sleep 1.5
((set_row++))

#echo -ne "\e["$set_row"H\e[7G\e[KConfig files complete"
echo -e "\e[7G\e[KConfig files complete"
kill-spinner 0
sleep 3
echo -e "\e[""$row""H\e[7G\e[JConfig files complete"
((row++))


echo -ne "\e[7G\e[JRestarting services"
show-spinner
echo -ne "\e[""$((row+1))""H\e[10G$YL*\e[12G$CL\e[JRestarting dnsmasq"
if systemctl restart dnsmasq  ; then
        echo -ne "\e[""$((row+2))""H\e[10G$YL*\e[12G$CL\e[JRestarting iptables"
        if systemctl restart iptables &> /dev/null ; then
                echo -ne "\e[""$((row+3))""H\e[10G$YL*\e[12G$CL\e[JApplying netplan settings"
                if netplan apply &> /dev/null ; then
			echo -ne "\e[""$((row+4))""H\e[10GWaiting for network..."
			test="google.com"
			while :; do # give network time to come back up
				if nc -zw1 $test 443 &> /dev/null && echo |openssl s_client -connect $test:443 2>&1 |awk '
					$1 == "SSL" && $2 == "handshake" { handshake = 1 }
					handshake && $1 == "Verification:" { ok = $2; exit }
					END { exit ok != "OK" }' &> /dev/null ; then
					break
				fi
                                dhclient "$wan_interface"
				sleep 1
			done
                        echo -e "\e[7G\e[JServices restarted"
                        kill-spinner 0
                        ((row++))
                else
                        kill-spinner 1
                fi
        else
                kill-spinner 1
        fi
else
        kill-spinner 1
fi # write config files


# install nordvpn
if ! which nordvpn &> /dev/null ; then
	echo -ne "\e[""$row""H\e[7G\e[JInstalling NordVPN application"
	show-spinner
        # this step is slightly modified from the official nordvpn steps.
        # In order to automate the installation the script is changed to assume yes. Same as -y on apt
        echo -ne "\e[""$((row+1))""H\e[10GGetting install script from NordVPN"
        while :; do
                if wget -q https://downloads.nordcdn.com/apps/linux/install.sh ; then
                        echo -ne "\e["$((row+1))"H\e[8G$YL""*""$CL""\e[7GRunning NordVPN install script"
                        if sed -i 's/ASSUME_YES=false/ASSUME_YES=true/' install.sh &> /dev/null && chmod +x install.sh &> /dev/null && ./install.sh &> /dev/null && rm install.sh &> /dev/null ; then
                                echo -ne "\e[""$((row+2))""H\e[8G$YL""*""$CL""\e[10GCleaning up"
                                if grep -i nordvpn < /etc/issue &> /dev/null || wget 'https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/script/header2' -qO - >> /etc/issue ; then
                                        if grep -i nordvpn < ~/.bashrc &> /dev/null || wget 'https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/script/header' -qO - >> ~/.bashrc ; then
                                                echo -e "\e[""$row""H\e[7G\e[JNordVPN installed successfully"
                                                kill-spinner 0
                                                ((row++))
                                                break
                                        else
                                                kill-spinner 4
                                                exit 31
                                        fi
                                else
                                        kill-spinner 4
                                        exit 32
                                fi
                        else
                                kill-spinner 4
                                exit 33
                        fi
                else
                for (( i = 0; i < 10; i++ )) ; do
                        if  nc -zw1 "$test" 443 &> /dev/null && echo |openssl s_client -connect "$test":443 2>&1 |awk '
                                $1 == "SSL" && $2 == "handshake" { handshake = 1 }
                                handshake && $1 == "Verification:" { ok = $2; exit }
                                END { exit ok != "OK" }' &> /dev/null ; then
                                break
                        else
                                if [[ $i -eq 6 ]] ; then
                                        kill-spinner 4
                                        exit 34
                                fi
                                sleep $i
                        fi
                done
                fi
        done
        if ! which nordvpn &> /dev/null ; then
                echo "$RD""Installation failed$CL"
                exit 99
        fi
else
	echo -e "\e[5G$success_mark\e[7GNordVPN is installed"
	kill-spinner 0 
	((row++))
fi # install nordvpn

# login to nordvpn
echo -ne "\e[""$row""H\e[7G\e[JLogin to NordVPN"
while :; do
        while :; do
                if [[ ! $(nordvpn account) =~ "not logged in" ]] ; then
                        echo -e "\e[5G$success_mark\e[7G$LTGN""You are logged in!$CL"
                        ((row++))
                        break
                fi
                echo -e "\e["$((row+1))"H\e[10GRequesting login link"
                a_login_url=("$(nordvpn login)")
                for url in "${a_login_url[@]}"; do
                        if [[ $url =~ (login-redirect) ]]; then
                                ((row++))
                                login_url=$url
                                break
                        else
                                sleep 2
                        fi
                        login_url=
                done
                if [[ -n $login_url ]] ; then
                        break
                fi
        done

        while :; do
                if [[ ! $(nordvpn account) =~ "not logged in" ]] ; then
                        break
                fi
                prompt-login-callback-msg "$login_url"
                echo -ne "$LTPP"
                read -r -p " > " callback_url && echo -ne "$CL"
                echo -ne "\e[""$row""H\e[7G\e[JLogging in to NordVPN"
                show-spinner
                if nordvpn login --callback "$callback_url" &> /dev/null ; then
                        echo -e "\e[5G$success_mark\e[7G\e[JLogged in to NordVPN"
                        kill-spinner 0
                        ((row++))
                        break
                else
                        echo -ne "\e[7GNordVPN failed to log in"
                        kill-spinner 3
                        if ! yes-no "NordVPN failed to log in. Do you want to try again. If you say no, you can try again from the command line using 'nordvpn login' then 'nordvpn login --callback'" "Y" ; then
                                echo -ne "\e[""$row""H\e[7G\e[K\e[JEverything installed but did not login to NordVPN. You can login from the cli using 'nordvpn login'\nYou will have to adjust your nordvpn settings from the cli as well using 'nordvpn set <setting> on|off'"
                                exit 31
                        else
                                echo -ne "\e[""$row""H\e[J"
                        fi
                fi
        done
        echo -ne "\e[7G""Applying NordVPN settings"
        show-spinner
        set_row=$((row+1))
        for nord_setting in "${nord_settings_actor[@]}" ; do
                echo -ne "\e[""$set_row""H\e[8G$YL*$CL\e[10G\e[jSetting $nord_setting"
		nordvpn set "${nord_setting}" # &> /dev/null ### testing
                ((set_row++))
        done
	sleep 5 ### testing
        nordvpn set analytics off &> /dev/null
        sleep 2
        echo -e "\e[""$row""H\e[7G\e[JNordVPN settings applied"
        kill-spinner 0
        ((row++))
        echo -ne "\e[""$row""H\e[7G""Enabling the monitor service"
        show-spinner
        systemctl daemon-reload &> /dev/null
        if chmod +x /root/check-connection.sh && systemctl enable nordvpn-net-monitor.service &> /dev/null ; then
		echo -e "\e[7GMonitor service enabled. The service will run on reboot."
		kill-spinner 0
		((row++))
	else
		echo -e "\e[7GMonitor service was not enabled and will not run when the system is started. Make sure the monitor script is in the correct location"
		kill-spinner 2
		((row++))
	fi
        break
done # login to nordvpn

echo -e "\e[""$((row+2))""H\e[10G$LTGN""Installation complete. Press any key to reboot..."
read -rsn1 -p ""
cleanup
reboot
