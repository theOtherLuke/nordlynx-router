#!/bin/bash

################################################################################
################################################################################
####################                                        ####################
####################         NOT PRODUCTION READY!!!        ####################
####################         NOT PRODUCTION READY!!!        ####################
####################         NOT PRODUCTION READY!!!        ####################
####################         NOT PRODUCTION READY!!!        ####################
####################         NOT PRODUCTION READY!!!        ####################
####################                                        ####################
################################################################################
################################################################################


LICENSE() {
	cat <<EOF
 MIT License

Copyright (c) 2024 nodaddyno

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
}
LICENSE && sleep 5

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
iptables_file=
net_file="/etc/netplan/config.yaml"
dnsmasq_file="/etc/dnsmasq.conf"

# check what distro so we install the correct packages using the correct package manager
release=$(cat /etc/*-release | grep NAME)
release=${release,,}

# Fedora, aka rpm distro
if [[ "$release" =~ (fedora|centos|almalinux) ]]; then # rpm distro
	if [[ "$release" =~ (centos|almalinux) ]]; then
		#enable epel repo for iptables-services, netplan.io, and systemd-networkd
		dnf upgrade -y
		dnf install 'dnf-command(config-manager)' -y
		dnf config-manager --set-enabled crb -y
		dnf install epel-release -y
		#we are using networkd as the backend
		dnf install systemd-networkd -y
		systemctl disable --now NetworkManager
		systemctl enable --now systemd-networkd
	fi
	# install basic dependencies and reconfigure base system
	dnf upgrade -y
	dnf install iptables-services dnsmasq dnsmasq-utils netplan.io nano -y
	dnf remove systemd-resolved -y
	systemctl disable --now NetworkManager
	systemctl enable --now iptables
	systemctl enable --now dnsmasq
	iptables_file="/etc/sysconfig/iptables"
	curl -o /etc/sysconfig/iptables https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/rules.v4
	curl -o /etc/netplan/config.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/config.yaml
	curl -o /etc/dnsmasq.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/dnsmasq.conf
# Ubuntu/Debian, aka deb distro
elif [[ "$release" =~ (ubuntu|debian) ]]; then # deb distro
	# install basic dependencies and reconfigure base system
	apt update && apt upgrade -y
	apt install iptables-persistent dnsmasq dnsmasq-utils netplan.io openvswitch-switch -y # openvswitch isn't strictly needed. only here to silence netplan error message that doesn't affect what we're doing
	apt purge systemd-resolved -y
	iptables_file="/etc/iptables/rules.v4"
	wget -O /etc/iptables/rules.v4 https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/rules.v4
	wget -O /etc/netplan/config.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/config.yaml
	wget -O /etc/dnsmasq.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/config-files/dnsmasq.conf
	# install dependencies to build ipcalc, Fedora/centos/almalinux has the correct version, debian/ubuntu must be built from source
	apt update
	if apt install meson ninja-build -y; then
		if wget https://gitlab.com/ipcalc/ipcalc/-/archive/1.0.3/ipcalc-1.0.3.tar && tar xvf ipcalc-1.0.3.tar && cd ipcalc-1.0.3 && meson setup build && ninja -C build && mv ./build/ipcalc /usr/bin; then
			echo "ipcalc build and install successful"
		else
			echo "Failed to build and install ipcalc. Exiting..."
			exit 6
		fi
	else
		echo "Unable to install dependencies to build ipcalc. ipcalc is required for this script to work as written."
		exit 5
	fi
	rm -rf ipcalc* # cleanup build files
else
	echo -e '\033[1;31m'"Only Debian, Ubuntu, Fedora, CentOS, and AlmaLinux are currently supported by this script."
	echo -e "You may try installing this manually by following the writeup."'\033[0;0m'
	exit 99
fi

# Populate list of wired network interfaces
system_interfaces=$(ls /sys/class/net)
for interface in $system_interfaces; do
	if [[ $interface =~ ^([e][ns|np|th]) ]]; then # starts with 'enp' 'ens' or 'eth'
		interfaces+=("$interface")
	fi
done
#warn about less than 2 network interfaces
if [ ${#interfaces[@]} -lt 2 ]; then
	echo -e '\033[1;92m'"Only "${#interfaces[@]}" interface available. If you need to add more network interfaces, do that now"
	read -p "Press [enter] to continue..."
	echo -e '\033[0m'
fi
#update list of interfaces
system_interfaces=$(ls /sys/class/net)
unset interfaces
for interface in $system_interfaces; do
	if [[ $interface =~ ^([e][ns|np|th]) ]]; then # starts with 'enp' 'ens' or 'eth'
		interfaces+=("$interface")
	fi
done

# checks for net.ipv4.ip_forward line
# adds or uncomments the line as needed
enable-forwarding() {
	if cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward' ; then
		if sed -i 's/^\(#net.ipv4.ip_forward.*\|net.ipv4.ip_forward\).*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf; then
			return $true
		else
			return $false
		fi
	else
		echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
		return $true
	fi
}

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

# prompt user to select lan and wan interfaces
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

# extracts first 3 octets from an ip address
#
# usage
#	get-subnet "address"
get-subnet() {
	OLD_IFS=$IFS
	IFS="." read -ra sn_array <<< "$1"
	subnet_prefix="${sn_array[0]}"."${sn_array[1]}"."${sn_array[2]}"
	echo "$subnet_prefix"
	return 1
	IFS=$OLD_IFS
}

# get octet at index in given ip address
#
# usage
#	get-octet "address" <index=3>
#
# returns octet at index
get-octet() {
	index=
	if [[ -z $2 ]]; then
		index=3
	else
		index=$2
	fi
	OLD_IFS=$IFS
	IFS="." read -ra oc_array <<< "$1"
	IFS=$OLD_IFS
	echo "${oc_array[$index]}"
	return "${oc_array[$index]}"
}

# prompts user for yes/no decision base don given prompt
#
# usage
#	yes-no "prompt" <default=y>
#
# returns true(yes) or false(no)
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
		read -n 1 -p $'\e[1;33m'"$1 ""$show_default"" "$'\e[0m' yn
		if [[ $yn == "" ]]; then
			yn=$default
		fi
		case $yn in
			[Yy]) return 0 ;;
			[Nn]) return 1 ;;
		esac
	done
}

# checks if given ip address is a valid private ip address
#
# usage
#	test-ip "address"
test-ip() {
        validip=$(ipcalc --class $1)
        if [[ "$validip" == *"Private"* ]] ; then
                return $true
        else
                return $false
        fi
}

# prompt user for lan ip address
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

# prompt user for rdhcp settings
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
                        read -r -p $'\n'"Please enter a valid subnet lease time"$'\n'"Enter dhcp pool lease timr : " dhcp_lease
                fi
        done

}

# checks if dhcp_end is larger or equal to dhcp_start
check-dhcp-pool() {
        if [[ $(get-octet $dhcp_end) -ge $(get-octet $dhcp_start) ]] ; then
                return $true
        else
                echo $false
        fi
}

setup-nord() {
        #systemctl stop nordvpn-net-monitor.service # temporarily stop th monitor service

        echo -e '\033[1;93m'"\nInstalling the NordVPN package..."'\033[0m'"\n"
        while :; do
				installed=
                if notinstalled=$(nordvpn) ; then
                        while :; do # loop until nordvpn login is successful
                        echo -e '\033[0m'
                        nord_account=$(nordvpn account)

                        if [[ "$nord_account" != *"not logged in"* ]] ; then
                                echo -e '\033[1;32m'"You are logged in!"'\033[0m'
                                return 0
                        fi
                        nordvpn login
                        echo
                        echo -e "\tCopy the link above and paste into your browser."
                        echo -e "\tLogin to your NordVPN account."
                        echo -e "\tClick CANCEL if it asks to open a new window."
                        echo -e "\tRight-click the CONTINUE button and copy link."
                        echo -e '\033[1;36m'
                        read -p "    Paste copied link here: " CALLBACK_LINK
                        echo -e '\033[1;32m'
                        echo "Logging in to NordVPN..."
                        echo -e '\033[0m'
                        nordvpn login --callback "$CALLBACK_LINK"

                        # check if NordVPN is logged in
                        nordvpn_account=$(nordvpn account)
                        if [[ "$nordvpn_account" == *"not logged in"* ]]; then
                                echo -e '\033[1;31m'"LOGIN FAILED! TRY AGAIN..."'\033[0m'
                                echo
                        else
        #                       systemctl start nordvpn-net-monitor.service # restart the monitor service
                                break
                        fi
                        done
                else
						echo -e '\033[1;33m'"A command not found error is normal. This is just checking if nordvpn is installed."'\033[0m'
                        if [[ "$release" =~ (fedora|centos|almalinux) ]]; then # rpm distro
								# this step is slightly modified from the official nordvpn steps.
								# In order to automate the installation the script is changed to assume yes. Same as -y on dnf
                                if curl -o install.sh https://downloads.nordcdn.com/apps/linux/install.sh && sed -i 's/ASSUME_YES=false/ASSUME_YES=true/' install.sh && chmod +x install.sh && ./install.sh && rm install.sh; then
                                                                        echo
                                                                else
                                                                        echo "NordVPN app failed to install..."
                                                                        exit 7
                                                                fi
                        elif [[ "$release" =~ (ubuntu|debian) ]]; then # deb distro
								# this step is slightly modified from the official nordvpn steps.
								# In order to automate the installation the script is changed to assume yes. Same as -y on apt
                                if wget https://downloads.nordcdn.com/apps/linux/install.sh && sed -i -r 's/ASSUME_YES=false/ASSUME_YES=true/' install.sh && chmod +x install.sh && ./install.sh && rm install.sh; then
                                                                        echo
                                                                else
                                                                        echo "NordVPN app failed to install..."
                                                                        exit 7
                                                                fi
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
		echo -e '\033[1;36m'"\nSelect your NordVPN Settings.\nPress [enter] to select the default for each.\n"'\033[0;0m'
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
		if yes-no "Do you need to whitelist port 22 for ssh on WAN?" "n"; then
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
   			nordvpn set lan-discovery on # required
			nordvpn set analytics off # I use a vpn for privacy, not so the vpn provider can collect data
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

	# Write network config file
	sed -i "s/lan_ip_address/$lan_ip/g" $net_file
	sed -i "s/lan_interface/$lan_interface/g" $net_file
	sed -i "s/wan_interface/$wan_interface/g" $net_file
	
	# Write dnsmasq config file
	sed -i "s/lan_interface/$lan_interface/g" $dnsmasq_file
	sed -i "s/dhcp_start/$dhcp_start/g" $dnsmasq_file
	sed -i "s/dhcp_end/$dhcp_end/g" $dnsmasq_file
	sed -i "s/dhcp_lease/$dhcp_lease/g" $dnsmasq_file

	# Write iptables rules file
	sed -i "s/lan_interface/$lan_interface/g" $iptables_file
	
	# enable ipv4 forwarding
	enable-forwarding
}

# pull the monitor script and service
# install and enable monitor service
setup-monitoring() { #note- rpm distros have curl but not wget standard, deb distros have wget but not curl standard, you can add wget to rpm or curl to deb
	if [[ "$release" =~ (fedora|centos|almalinux) ]]; then # add other rpm distros by separating with a pipe '|' eg- (fedora|centos|etc)
		curl -o /root/check-connection.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/check-connection.sh
		chmod +x /root/check-connection.sh
		curl -o /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/nordvpn-net-monitor.service
		systemctl daemon-reload
		systemctl enable --now nordvpn-net-monitor
	elif [[ "$release" =~ (debian|ubuntu) ]]; then # add other deb distros by separating with a pipe '|' ubuntu should 
		wget -O /root/check-connection.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/check-connection.sh
		chmod +x /root/check-connection.sh
		wget -O /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/main/monitor-script/nordvpn-net-monitor.service
		systemctl daemon-reload
		systemctl enable --now nordvpn-net-monitor
	fi	
}

while :; do

	#select network interfaces
	assign-interfaces

	#get ip address from user
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
	echo -e '\033[1;36m'"SETTINGS"'\033[0;0m'
	echo
	echo -e '\033[1;34m'"LAN IPv4   : "'\033[0;0m'$lan_ip
	echo -e '\033[1;34m'"DHCP start : "'\033[0;0m'$dhcp_start
	echo -e '\033[1;34m'"DHCP end   : "'\033[0;0m'$dhcp_end
	echo -e '\033[1;34m'"DHCP lease : "'\033[0;0m'$dhcp_lease
	echo
	echo -e '\033[1;36m'
	if yes-no "Save these settings?"; then
		save-settings
		if setup-nord ; then
			#create iptables
			echo -e '\033[1;36m'"Creating iptables..."'\033[0m'
			#get and save nordvpn settings
			save-nord-settings
			#setup monitoring service
			echo -e '\033[1;36m'"Installing monitoring service..."'\033[0m'
			setup-monitoring
			echo
			echo -e '\033[1;33m'"NordVPN Router setup complete!\n"'\033[0m'
			if [[ $(nordvpn settings | grep Auto-connect) =~ (enabled) ]]; then
				echo "NordVPN will connect automatically on reboot."
			else
				echo "NordVPN Auto-connect is not enabled. It will need to be manually connected after reboot."
			fi
			echo -e
			read -n 1 -p "Press any key to reboot..."
			reboot || while :; do echo bye...;done
			exit 0
		else
			echo "Failed to setup NordVPN package..."
			exit 1
		fi
	else
			if yes-no "Try again?"; then
					break
			else
					exit 1
		   fi
	fi
done
