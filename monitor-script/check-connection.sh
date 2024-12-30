#!/usr/bin/env bash
#set -x

license(){
    echo -e '\033[1;32m'
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
    echo -e '\033[0m'
}

license

cleanup() {
    disconnect
    jobs -p | xargs kill &> /dev/null
    exit
}

trap cleanup EXIT INT SIGINT

######################################################################
# check-connection v.2.2.2
#
# For more verbosity, add '-v' to the command call:
#       '/path/to/check-connection.sh -v'
#
# To specify a country, either change the default in this script, or
# add '-c <country>' to the command call:
#       '/path/to/check-connection.sh -c <country>'
# use -c to delare a p2p server instead of a country:
#       '/path/to/check-connection.sh -c p2p'
# 
# both options may be used together

### VARIABLES
true=0
false=1
post_quantum=$true
verbose=$false
wan_interface=wan_iface
wan_is_static=$false
exit_on_bad_country_code=$false # change this to $true if you want to exit on invalid country code
country=pref_country
connected=$false
# I monitor my gateways over a seperate interface
kill_monitor_on_loss=$true
kill_existing_connection=$true # disable to keep existing connections when starting the script
monitor_interface=eth81

while (( "$#" )); do
    case "$1" in
        -v)
            verbose=$true
            shift
            ;;
        -c)
            if [[ -n "$2" ]]; then
                country="${2,,}" # Convert to lowercase
                case "$country" in
                    us|united_states) country="United_States" ;;
                    ca|canada) country="Canada" ;; # Ohhhh Caaanadaaaa...jk, I Love my northern neighbors, eh!
                    fr|france) country="France" ;; # Oui Oui!
                    es|spain) country="Spain" ;;
                    uk|gb|united_kingdom) country="United_Kingdom" ;;
                    bz|belize) country="Belize" ;;
                    mx|mexico) country="Mexico" ;; # ¡Orale!...¡También quiero a mis vecinos del sur!
                    p2p) country="p2p" ;; # nordvpn will not accept p2p and country at the same time, so this is not a problem
                    *)
                        echo "[ $(date) ] Country not in script listing: $country, but we're still gonna try!"
                        ;;
                esac
                shift 2
            else
                echo "Error: -c requires a country argument" >&2 | tee -a "$logfile"
                exit 1
            fi
            ;;
        *)
            echo "Ignoring unknown argument: $1"
            shift
            ;;
    esac
done

test_country=$(echo "$country" | sed -r 's/_/ /')
echo "Selected country : $test_country"

logfile="/var/log/nordvpn/monitor.log"
if [[ ! -d "$(dirname "$logfile")" ]] ; then
    mkdir -p "$(dirname "$logfile")"
fi
if [[ -f $logfile ]] ; then
    mv $logfile $logfile.old # could be rewritten as `mv $logfile $logfile.$(date +%F_%T)` to append current date and time and preserve older logs
fi

### FUNCTIONS
# Check for a connected WAN interface. works for wired and wireless alike.
# Will trap here in a loop until it sees a connection on the WAN interface.
# If previously connected and loses connection, will disconnect nordvpn.
# Always returns $true because it loops until it is $true.
check-wan() {
    [ $verbose == $true ] && echo "[ $(date) ] We are using $wan_interface for WAN. Checking connection..." | tee -a $logfile
    if [[ $wan_interface =~ ^([w][lp|lan|lo]) ]] ; then
        while ! ip a | grep $wan_interface &> /dev/null ; do
            sleep 3
        done
    fi
    if ! ip -br a show $wan_interface | grep UP &> /dev/null ; then
        if [[ "$connected" == "$true" ]] ; then
            echo "[ $(date) ] WAN is DOWN!" | tee -a $logfile
            connected=$false
            systemctl restart nordvpnd.service
        fi
        disconnect &
        echo "[ $(date) ] WAN is not connected: Waiting for connection..." | tee -a $logfile
        while ! ip -br a show $wan_interface | grep UP &> /dev/null ; do # if DOWN, traps until UP
            sleep 10
        done
        while ! ip a show $wan_interface | grep inet &> /dev/null ; do
            sleep 5 # give dhcp a chance to give an address on its own
            if [[ "$wan_is_static" == "$false" ]] && ip a show $wan_interface | grep UP && ! ip a show $wan_interface | grep inet ; then
                if ! dhclient $wan_interface &> /dev/null ; then # request an address
                    echo "[ $(date) ] Unable to get address from dhcp server. Check settings." | tee -a $logfile
                    sleep 10
                else
                    return $true
                fi
            fi
        done
        return $true
    elif ip -br a show $wan_interface | grep UP &> /dev/null ; then
        return $true
    else
        echo "[ $(date) ] Unknown WAN state. Exiting..." | tee -a $logfile
        ip -br a show $wan_interface | tee -a $logfile
        [ $kill_monitor_on_loss == $true ] && monitor-updown down
        systemctl stop nordvpn-net-monitor.service
        exit 3
    fi
}

# Check the connection status of nordvpn
# returns $true if nordvpn is connected
check-vpn() {
    vpn_status=$(nordvpn status)
    server=$(echo "$vpn_status" | grep Server)
    if [[ "$vpn_status" =~ (Connected) ]]; then
        if [[ "$vpn_status" == "$test_country" ]] ; then
            [ $verbose == $true ] && echo "[ $(date) ] NordVPN is connected to preferred country: $test_country" | tee -a $logfile
            [ $verbose == $true ] && echo "[ $(date) ] NordVPN is connected to $server" | tee -a $logfile
            connected=$true
            return $true
        elif [[ "$country" =~ (p2p) ]] ; then
            [ $verbose == $true ] && echo "[ $(date) ] NordVPN is connected to $server" | tee -a $logfile
            connected=$true
            return $true
        else
            connected=$false
            return $false
        fi
    else
        connected=$false
        return $false
    fi
}

connect-vpn() {
	while :; do
        if [[ "$post_quantum" == "$true" ]] ; then
            # an unknown issue with post-quantum prevents reconnecting. Disabling and re-enabling the feature seems to help
            nordvpn set post-quantum off &> /dev/null
            sleep 5
            nordvpn set post-quantum on &> /dev/null
        fi
		echo "[ $(date) ] Connecting to NordVPN: $test_country" | tee -a $logfile
		while read -r result ; do # read and process output from fd 3
			echo -e "[ $(date) ] $result" | tee -a $logfile
			if [[ "$result" =~ (aborted|canceled) ]] ; then
				sleep 8 # waiting to try connect again
				check-wan
			elif [[ "$result" =~ (You are connected) ]] ; then
				connected=$true
				return $true
			elif [[ "$result" =~ (does not exist) ]] ; then
				if [[ "$exit_on_bad_country_code" == "$true" ]] ; then
					echo -e "[ $(date) ] Invalid country code specified: $country\n\tStopping nordvpn-net-monitor.service and exiting..." | tee -a $logfile
					systemctl stop nordvpn-net-monitor.service
					exit 4
				else
					echo -e "[ $(date) ] Invalid country code specified: $country\n\tSetting to auto-select country..." | tee -a $logfile
					country=''
					sleep 3
				fi
			elif [[ "$result" =~ (already in progress) ]] ; then
				while jobs -l | grep Running &> /dev/null ; do
					jobs -p | xargs kill -INT &> /dev/null
				done
				return $false
			fi
		done < <(connect "$country")
	done
}

# makes 1 attempt to connect to nordvpn. try to kill attempt after timeout
# usage:
#   connect <options>
connect() {
    args=$*
    nordvpn c "$args" &
    sleep 7
    jobs -p | xargs kill -INT &> /dev/null
}

disconnect() {
    nordvpn d &> /dev/null
    [ $kill_monitor_on_loss == $true ] && monitor-updown down
}

monitor-updown() {
    case "$1" in
        up|down) ip link set dev "$monitor_interface" "$1" ;;
        *) ;;
    esac
}

check-connectivity() {
    test=google.com
    if [[ "$verbose" == "$true" ]] ; then
        echo -e "[ $(date) ] Checking internet connectivity..." | tee -a $logfile
        echo -e "[ $(date) ] Reaching out to $test" | tee -a $logfile
    fi
    if nc -zw1 $test 443 && echo |openssl s_client -connect $test:443 2>&1 |awk '
    $1 == "SSL" && $2 == "handshake" { handshake = 1 }
    handshake && $1 == "Verification:" { ok = $2; exit }
    END { exit ok != "OK" }'; then
        [ $verbose == $true ] && echo "[ $(date) ] We have connectivity!" | tee -a $logfile
        return $true
    else
        echo "[ $(date) ] We have no connectivity!" | tee -a $logfile
        return $false
    fi
}

check-account-status() {
    echo "[ $(date) ] Checking account status..." | tee -a $logfile
    nord_account="$(nordvpn account)"
    if [[ "$nord_account" =~ "not logged in" ]] ; then
        echo -e "[ $(date) ] You are not logged in. You must be logged into an active NordVPN account.\n\tExiting and stopping service..." | tee -a $logfile
        monitor-updown down
        systemctl stop nordvpn-net-monitor.service
        exit
    elif [[ "$nord_account" =~ "Account Information" ]] ; then
        echo "[ $(date) ] You are logged in to NordVPN!"
    else
        if [[ "$(nordvpn status)" =~ (Connected) ]] ; then
            disconnect
        fi
        sleep 10
        systemctl restart nordvpn-net-monitor.service
        exit 1
    fi
}

# Monitor WAN and nordvpn connection, act accordingly.
# Check-wan always returns true because it traps in a loop until we have a wan connection.
# We could add some time limit or loop counter to prevent infinite waiting or to notify
# admin of a persistent problem
maintain() {
    while check-wan ; do
        echo "[ $(date) ] WAN is connected" | tee -a $logfile
        if check-connectivity ; then
            echo "[ $(date) ] We have connectivity!" | tee -a $logfile
            if check-vpn ; then
                echo "[ $(date) ] VPN is active." | tee -a $logfile
                sleep 10
                while check-wan && check-connectivity ; do
                    [ $verbose == $true ] && echo "[ $(date) ] WAN is connected" | tee -a $logfile
                    if check-vpn ; then
                        [ $verbose == $true ] && echo "[ $(date) ] VPN is active." | tee -a $logfile
                        monitor-updown up
                        sleep 10
                    else
                        disconnect
                        break # send it back to the outer loop
                    fi
                done
            else
                disconnect
                if ! connect-vpn ; then
                    echo "[ $(date) ] Failed to connect to vpn" | tee -a $logfile
                fi
            fi
        else
            sleep 10
            ip -br a show
        fi
    done
}

### run the script:
# Initial check-wan(), cannot check account status if we don't have WAN connection
# check-wan() traps in a loop until it has WAN connection
# All logic is handled through the maintain() function after startup
check-wan
if [[ ! "$(nordvpn status)" =~ (Connected) ]]; then check-account-status; fi

# babysit the connection
maintain
