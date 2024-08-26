#!/bin/bash



#set -x

# empty array to contain network interfaces
declare -a interfaces
# true and false are not needed. I use them for readability
true=0
false=1
lan_ip=
dhcp_start=
dhcp_end=
dhcp_lease=
wan_interface=
lan_interface=
subnet_prefix=
net_file=

# install basic dependencies and reconfigure base system
systemctl disable --now systemd-resolved
dnf upgrade
dnf install iptables-services dnsmasq dnsmasq-utils netplan nano -y
systemctl disable --now NetworkManager
systemctl disable --now systemd-firewalld
systemctl enable --now iptables
systemctl enable --now dnsmasq

# pull iptables file from git repository and save to proper location
# this file assumes eth1 is the lan interface. I may change it later to be more portable
curl -o /etc/sysconfig/iptables https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/debian-config-files/rules.v4

# Populate list of wired network interfaces
system_interfaces=$(ls /sys/class/net)
for interface in $system_interfaces; do
	if [[ $interface =~ ^([e][ns|np|th]) ]]; then # starts with 'enp' 'ens' or 'eth'
		interfaces+=("$interface")
	fi
done

#warn about less than 2 network interfaces
if [ ${#interfaces[@]} -lt 2 ]; then
	echo -e "Only "${#interfaces[@]}" available. "'\033[1;36m\'"If you need to add more network interfaces, do that now"'\033[0;0m'"\n"
	read -p "Press [enter] to continue..."
fi

#update list of interfaces
system_interfaces=$(ls /sys/class/net)
unset interfaces
for interface in $system_interfaces; do
	if [[ $interface =~ ^([e][ns|np|th]) ]]; then # starts with 'enp' 'ens' or 'eth'
		interfaces+=("$interface")
	fi
done

#enable ipv4 forwarding
if cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward' ; then
	if sed -i 's/^\(#net.ipv4.ip_forward\|net.ipv4.ip_forward\).*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf; then
		return 0
	else
		return 1
	fi
else
	echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	return 0
fi

#### FUNCTIONS ####

# display interfaces in a friendly manner
show-interfaces() {
        echo -e '\033[1;32m'"\nAvailable ethernet interfaces: \n"'\033[0;0m'
        for (( i = 0; i < ${#interfaces[@]}; i++ ))
        do
                if [ $i -ge ${#interfaces[@]} ]; then
                        break
                else
                        echo -e '\033[1;35m'"\t$i :"'\033[0;0m'"\t${interfaces[$i]}"
                fi
        done
}

# assign network interfaces
assign-interfaces() {
        while :; do
                show-interfaces
                while :; do
                        read -r -n 1 -p $'\n'"Select WAN interface :" wan_selection
                        if [ $wan_selection -le ${#interfaces[@]} ]; then
                                wan_interface=${interfaces[$wan_selection]}
                                break
                        fi
                done
                while :; do
                        read -r -n 1 -p $'\n'"Select LAN interface :" lan_selection
                        if [ $wan_selection -le ${#interfaces[@]} ]; then
                                lan_interface=${interfaces[$lan_selection]}
                                break
                        fi
                done
                echo
                echo -e "\n\tWAN :\t""$wan_interface"
                echo -e "\tLAN :\t""$lan_interface"
                echo
                if yes-no "Confirm interfaces"; then
                        echo -e "\nSetting interfaces...\n"
                        break
                fi
        done
}

# extract frist 3 octets from ipv4 address as the subnet
#
# usage
#		get-subnet $address
get-subnet() {
        OLD_IFS=$IFS
        IFS="." read -ra sn_array <<< "$1"
        subnet_prefix="${sn_array[0]}"."${sn_array[1]}"."${sn_array[2]}"
        echo "$subnet_prefix"
        return 1
        IFS=$OLD_IFS
}

# gets the value of the given octet within an ipv4 address
# I use this to check the last octet of host, dhcp_start, and dhcp_end for conflicts
#
# usage
#		get octet $address <$index=3>
get-octet() {
                which_one=
                if [[ -z $2 ]]; then
                        which_one=3
                else
                        which_one=$2
                fi
        OLD_IFS=$IFS
        IFS="." read -ra oc_array <<< "$1"
        IFS=$OLD_IFS
        echo "${oc_array[$which_one]}"
        return "${oc_array[$which_one]}"
}

# displays yes/no prompt and returns true or false
#
# usage
#		yes-no $prompt
yes-no() {
	while :; do
		read -n 1 -p $'\e[1;33m'"$* [Y|n] "$'\e[0m' yn
		if [[ $yn == "" ]]; then
			yn="y"
		fi
		case $yn in
			[Yy]) return 0 ;;
			[Nn]) return 1 ;;
		esac
	done
}

# uses ipcalc to determine if an ipv4 address is a valid private address
#
# usage
#		test-ip $address
test-ip() {
# this requires ipcalc, installed by default on fedora
	validip=$(ipcalc --class $1)
	if [[ "$validip" == *"Private"* ]] ; then
		return 0
	else
		return 1
	fi
}

# get the lan ipv4 address from the user, assigns to global variable
get-lan-ipv4() {
	read -r -p "Enter valid private IPv4 address for LAN : " lan_ip
	while :; do
		if (test-ip $lan_ip) ; then
			break
		else
			read -r -p $'\n'"Invalid IPv4 address..."$'\n'"Please enter a valid private IPv4 address : " lan_ip
		fi
	done
}

# get dhcp pool start, end, and lease time from user, assigns to global variables
get-dhcp-pool() {
	read -r -p "Enter dhcp pool starting address : " dhcp_start
	while :; do
		dhcp_subnet=$(get-subnet $dhcp_start)
		if [[ "$dhcp_subnet" == "$lan_subnet" ]] ; then
			if (test-ip $dhcp_start) ; then
				break
			else
				read -r -p $'\n'"Please enter a valid address in the same network as the LAN"$'\n'"Enter dhcp pool starting address : " dhcp_start
			fi
		else
			read -r -p $'\n'"Please enter a valid address in the same network as the LAN"$'\n'"Enter dhcp pool starting address : " dhcp_start
		fi
	done
	read -r -p "Enter dhcp pool ending address : " dhcp_end
	while :; do
	dhcp_subnet=$(get-subnet $dhcp_end)
	if [[ "$dhcp_subnet" == "$lan_subnet" ]] ; then
		if (test-ip $dhcp_end) ; then
			break
		else
			read -r -p $'\n'"Please enter a valid address in the same network as the LAN"$'\n'"Enter dhcp pool ending address : " dhcp_end
		fi
	else
		read -r -p $'\n'"Please enter a valid address in the same network as the LAN"$'\n'"Enter dhcp pool ending address : " dhcp_end
	fi
	done
	read -r -p "Please enter the DHCP lease time [1-99999][h|m|s] : " dhcp_lease
	while :; do
		if [[ "$dhcp_lease" =~ ^([1-9]{1,5})h|m|s$ ]] ; then
			break
		else
			read -r -p $'\n'"Please enter a valid subnet lease time"$'\n'"Enter dhcp pool lease time : " dhcp_lease
		fi
	done
}

# checks the dhcp start and end addresses to ensure end is after start
check-dhcp-pool() {
        if [[ $(get-octet $dhcp_end) -ge $(get-octet $dhcp_start) ]] ; then
                return 0
        else
                return 1
        fi
}

# use nordvpn script to install the nordvpn package and login to nordvpn
setup-nord() {
	# colors
	LTBLUE='\033[1;36m'
	LTGREEN='\033[1;32m'
	LTRED='\033[1;31m'
	NO_COLOR='\033[0;0m'

	while :; do
		if notinstalled=$(nordvpn) ; then
			while :; do # loop until nordvpn login is successful
			echo -e ${NO_COLOR}
			nord_account=$(nordvpn account)

			if [[ "$nord_account" != *"not logged in"* ]] ; then
				echo -e ${LTGREEN}"You are logged in!"${NO_COLOR}
				return 0
			fi
			nordvpn login
			echo
			echo -e "\tCopy the link above and paste into your browser."
			echo -e "\tLogin to your NordVPN account."
			echo -e "\tClick CANCEL if it asks to open a new window."
			echo -e "\tRight-click the CONTINUE button and copy link."
			echo -e ${LTBLUE}
			read -p "       Paste copied link here: " CALLBACK_LINK
			echo -e ${LTGREEN}
			echo "Logging in to NordVPN..."
			echo -e ${NO_COLOR}
			nordvpn login --callback "$CALLBACK_LINK"

			# check if NordVPN is logged in
			nordvpn_account=$(nordvpn account)
			if [[ "$nordvpn_account" == *"not logged in"* ]]; then
				echo -e ${LTRED}"LOGIN FAILED! TRY AGAIN..."${NO_COLOR}
			else
				break
			fi
			done
		else # if nordvpn is not installed, install it
			if curl -o install.sh https://downloads.nordcdn.com/apps/linux/install.sh && sed -i 's/ASSUME_YES=false/ASSUME_YES=true/' install.sh && chmod +x install.sh && ./install.sh && rm install.sh; then
				echo
			else
				echo "NordVPN app failed to install..."
				exit 7
			fi
		fi
	done
}

save-nord-settings() {
	while :; do
		n_tpl=
		n_virtual=
		n_whitelist=
		n_auto=
		echo -e "\n"
		if yes-no "Enable NordVPN Threat Protection Lite?"; then
			n_tpl="on"
		else
			n_tpl="off"
		fi
		echo -e "\n"
		if yes-no "Enable NordVPN Virtual Location?"; then
			n_virtual="on"
		else
			n_virtual="off"
		fi
		echo -e "\n"
		if yes-no "Enable NordVPN Autoconnect?"; then
			n_auto="on"
		else
			n_auto="off"
		fi
		echo -e "\n"
		echo -e '\033[1;31m'"WARNING!\n\n\tPORT 22 SHOULD ONLY BE WHITELISTED TO CONFIGURE OVER THE WAN INTERFACE, AND SHOULD BE REMOVED AFTER COMPLETION.\n"'\033[0;0m'
		if yes-no "Do you need to whitelist port 22 for ssh on WAN?"; then
			n_whitelist="on"
		else
			n_whitelist="off"
		fi
		echo -e "\n"
		echo
		echo -e "NordVPN Settings :\n"
		echo -e "\tThreat Protections Lite  : "$n_tpl
		echo -e "\tVitual Location          : "$n_virtual
		echo -e "\tAutoconnect              : "$n_auto
		echo -e "\tWhitelist port 22 (ssh)  : "$n_whitelist
		echo
		if yes-no "Confirm these settings :"; then
			# set nordvpn settings
			nordvpn set routing on # required
			nordvpn set analytics off
			nordvpn set tpl $n_tpl
			nordvpn set virtual-location $n_virtual
			nordvpn set autoconnect $n_auto
			if [ "$n_whitelist" == "on" ]; then
				nordvpn whitelist add port 22
			fi
			return
		else
			echo -e "\n\n\n"
		fi
	done
}

save-settings() {
	echo "Saving..."

	# Write network config file, the spaces are critical for proper function in netplan config files
	echo -e "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    "$wan_interface":\n      dhcp4: true\n    "$lan_interface":\n      addresses:\n      - "$lan_ip"/24" > /etc/netplan/config.yaml
	# Write dnsmasq config file
	cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
	echo > /etc/dnsmasq.conf
	echo "interface=""$lan_interface" >> /etc/dnsmasq.conf
	echo "dhcp-range="$dhcp_start","$dhcp_end","$dhcp_lease >> /etc/dnsmasq.conf
	echo -e '\033[1;36m'"Settings Saved!"'\033[0;0m'
}

setup-monitoring() {
	# Pull monitor service files from git repository, install, and enable
	curl -o /root/check-connection.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/check-connection.sh
	chmod +x /root/check-connection.sh
	curl -o /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/nordvpn-net-monitor.service
	systemctl enable nordvpn-net-monitor
	systemctl daemon-reload
	if yes-no "Do you wish to start the monitor service now? (The service will start automatically on reboot) "; then
		systemctl start nordvpn-net-monitor
	fi
}

#### RUN ####
# execute inside loop until the conditions are satisfied
while :; do
	#select network interfaces
	assign-interfaces

	#get lan ipv4 address from user
	get-lan-ipv4

	#extract first 3 octets from ip address, to make sure we are in the same network
	lan_subnet=$(get-subnet $lan_ip)

	#get dhcp pool from user
	while :; do
		get-dhcp-pool
		if check-dhcp-pool; then
			break
		fi
	done
	#display network settings and confirm
	echo -e "\n\n\n"
	echo -e '\033[0;92m'"SETTINGS"'\033[0;0m'
	echo
	echo -e '\033[1;34m'"LAN IPv4   : "'\033[0;0m'$lan_ip
	echo -e '\033[1;34m'"DHCP start : "'\033[0;0m'$dhcp_start
	echo -e '\033[1;34m'"DHCP end   : "'\033[0;0m'$dhcp_end
	echo -e '\033[1;34m'"DHCP lease : "'\033[0;0m'$dhcp_lease
	echo

	if yes-no "Save these settings?"; then
		save-settings
		if setup-nord ; then
			#get and save nordvpn settings
			save-nord-settings
			#setup monitoring service
			setup-monitoring
			if yes-no "Connect now? "; then
				nordvpn c
			fi
			echo
			echo -e "NordVPN Router setup complete!"
			echo -e "\tIf you haven't connected yet, you can do so by running 'nordvpn c'"
			echo -e
			read -n 1 -p "Press any key to reboot..."
			reboot                                                                        
			exit 0
		fi
	else
		if yes-no "Try again?"; then
			echo
		else
			echo boo
			exit 1
	   fi
	fi
done
