#!/bin/bash
#
# My script to monitor and recover nordvpn connections
# It's redundant, but I integrated a function to bring the lan interface up an down
#
# As always, YMMV
#
# USE AT YOUR OWN RISK
# 
# As with the rest of this project, make sure to change the details to match your setup
#
# my LAN interface is enp6s19

logfile="/var/log/nordvpn/monitor.log"

ifup enp6s19

check_lan_state() {
        lan_stat=$(ip a | grep enp6s19)
        if [[ "$lan_status" == *"UP"* ]]; then
                return $true
        else
                echo "[ "$(date)" ] LAN is down!" | tee -a $logfile
                return $false
        fi
}

kill_lan() {
        if ! check_lan_state; then
                if (( $( ifdown enp6s19 ))); then
                        return $true
                else
                        return $false
                fi
        fi
}

revive_lan() {
        if (( $( ifup enp6s19 ))); then
                return $true
        else
                return $false
        fi
}

try_reconnect() {
        if (( $( nordvpn c ))); then
                return $true
        else
                if (( $(nordvpn d && nordvpn c))); then
                        return $true
                fi
                return $false
        fi
}

reboot_system() {
        echo "[ "$(date)" ] Rebooting..." | tee -a $logfile
        touch /reboot.hold # create empty file to indicate system has been rebooted by this script
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

while :; do
        echo "[ "$(date)" ] Checking connectivity..." | tee -a $logfile
        if ! check_connectivity; then # if disconnected
                echo -e "[ "$(date)" ] No connection!\nAttempting to reconnect" | tee -a $logfile
                if ! try_reconnect; then # if couldn't reconnect
                        if ! check_connection; then # check if connection failed
                                if ! restart_services; then # check if services restarted
                                        if ! check_connection; then # check if restarting services failed to fix the connection
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
        if [ -f /reboot.hold ]; then
                rm /reboot.hold
        fi
        sleep 10
done
