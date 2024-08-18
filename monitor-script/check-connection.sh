#!/bin/bash
#
# My script to monitor and recover nordvpn connections
# This script should work with Debian, Ubuntu, and Fedora
# It's redundant, but I integrated a function to bring the lan interface up and down
#
# Please, feel free to notify me of any issues or fixes you find with this new version of the script
#
# As always, YMMV
#
# USE AT YOUR OWN RISK
# 
# As with the rest of this project, make sure to change the details to match your setup
#
# my LAN interface is eth1

country="US"
logfile="/var/log/nordvpn/monitor.log"
lan_interface=eth1
ifup $lan_interface

check_lan_state() { # returns true if interface is up
        lan_stat=$(ip a | grep $lan_interface)
#       if (( -z "$( ip a | grep $lan_interface | grep 'state UP' )")); then
        if [[ "$lan_stat" == *"UP"* ]]; then
                return $true
        else
                echo "[ "$(date)" ] LAN is down!" | tee -a $logfile
                return $false
        fi
}

check_vpn_status() {
        while :; do
                vpn_status=$(nordvpn status)
                sleep 5
                if [[ "$vpn_status" == *"Connected"* ]]; then # Check if vpn is connected
                        if [[ "$vpn_status" == *"United States"* ]]; then # Check if vpn is connected to correct country
                                echo "[ "$(date)" ] NordVPN is connected to preferred country: "$country"" | tee -a $logfile
                                return $true
                        else
                                echo "[ "$(date)" ] NordVPN not connected to preferred country! Reconnecting..." | tee -a $logfile
                                if ! try_reconnect; then
                                        return $false
                                fi
                        fi
                        return $true
                else
                        if ! try_reconnect; then
                                return $false
                        fi
                fi
        done
}

kill_lan() {
        if ! check_lan_state; then
                if (( $( ifdown $lan_interface ))); then
                        return $true
                else
                        return $false
                fi
        fi
}

revive_lan() {
        if (( $( ifup $lan_interface ))); then
                return $true
        else
                return $false
        fi
}

try_reconnect() {
        if (( $( nordvpn c $country ))); then
                return $true
        else
                if (( $(nordvpn d && nordvpn c $country ))); then
                        return $true
                fi
                return $false
        fi
}

reboot_system() {
        echo "[ "$(date)" ] Rebooting..." | tee -a $logfile
        touch /reboot.hold
        reboot
}

check_connectivity() {
        test=google.com
        echo -e "[ "$(date)" ] Checking internet connectivity...\n\tReaching out to "$test"" | tee -a $logfile

        if nc -zw1 $test 443 && echo |openssl s_client -connect $test:443 2>&1 |awk '
        $1 == "SSL" && $2 == "handshake" { handshake = 1 }
        handshake && $1 == "Verification:" { ok = $2; exit }
        END { exit ok != "OK" }'; then
                echo "[ "$(date)" ] We have connectivity!"
                return $true
        else
                echo "[ "$(date)" ] Confirming LAN is down:" | tee -a $logfile
                if check_lan_state ; then
                        echo "[ "$(date)" ] We have NO connectivity..." | tee -a $logfile
                        echo "[ "$(date)" ] Killing LAN..." | tee -a $logfile
                        if kill_lan ; then
                                echo
                        fi
                fi
                return $false
        fi
}

setup_log() {
        templog=$(tail -n 50 /var/log/nordvpn/monitor.log) 
        echo "$templog" >> /var/log/nordvpn/monitor.log
}

setup_log

# initial check to see if nordvpn is logged in
echo "[ "$(date)" ] Checking account status..." | tee -a $logfile
nord_account=$(nordvpn account)
echo -e "[ "$(date)" ] Account status:\n"$nord_account | tee -a $logfile
if [[ "$nord_account" == *"not logged in"* ]] ; then
        systemctl stop nordvpn-net-monitor.service
        exit
fi


echo "[ "$(date)" ] Establishing VPN connection..." | tee -a $logfile
nordvpn c $country



while :; do
        echo "[ "$(date)" ] Checking VPN status..." | tee -a $logfile
        if ! check_vpn_status; then # check vpn status
                echo "[ "$(date)" ] Checking connectivity..." | tee -a $logfile
                if ! check_connectivity; then # if disconnected
                        echo -e "[ "$(date)" ] No connection!\nAttempting to reconnect" | tee -a $logfile
                        if ! try_reconnect; then # if couldn't reconnect
                                if ! check_connectivity; then # check if connection failed
                                        if ! restart_services; then # check if services restarted
                                                if ! check_connectivity; then # check if restarting services fixed the connection
                                                        if [ -f /reboot.hold ]; then
                                                                rm  /reboot.hold
                                                                echo "[ "$(date)" ] Failed to reconnect! Disabling VPN..." | tee -a $logfile
                                                                nordvpn set autoconnect off
                                                                nordvpn set killswitch on
                                                                nordvpn d
                                                                exit 1
                                                        else
                                                                reboot_system
                                                        fi
                                                fi
                                        fi
                                fi
                        fi
                fi
        fi
        if [ -f /reboot.hold ]; then
                rm /reboot.hold
        fi
        sleep 10
done
