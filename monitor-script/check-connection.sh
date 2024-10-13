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

######################################################################
# check-connection v.2
#
# This is almost a complete re-write. I kept modified versions of 2
# functions and replaced the rest. Hopefully this new version is
# more efficient and robust.
# For more verbosity, add '-v' to the command call:
#       '/path/to/check-connection.sh -v'
# To specify a country, either change the default in this script, or
# add '-c <country>' to the command call:
#       '/path/to/check-connection.sh -c <country>'
# both options may be used together

### VARIABLES
true=0
false=1
verbose=$false
exit_on_bad_country_code=$false # change this to $true if you want to exit on invalid country code
country="United_States"
for (( i = 1; i <= $#; i++ )) ; do # we start at 1 because 0 is the script location or shell name, depending on how we ran the script
    case "${!i}" in
        -v) verbose=$true ;;
        -c) # country
                        j=$((i+1))
                        !j="${!j,,}"
                        country="${!j,,}" # make it lowercase
                        case "$country" in
                                us|"united states"|united_states) country="United_States" ;;
                                ca|canada) country="Canada" ;; # Ohhhh Caaanadaaaa...jk, I Love my northern neighbors!
                                fr|france) country="France" ;; # Wi wi!
                                es|spain) country="Spain" ;;
                                uk|gb|"united kingdom"|united_kingdom) country="United_Kingdom" ;;
                                bz|belize) country="Belize" ;;
                                mx|mexico) country="Mexico" ;; # ¡Orale!...¡También quiero a mis vecinos del sur!
                                # etc.
                                *) echo -e "[ $(date) ] Country not in script listing : ${!j}, but we're still gonna try!" | tee -a $logfile ; country="${!j}" ;;
                        esac
                        ;;
        *) echo "Ignoring unknown argument: ${!i}" ;;
    esac
done
test_country=$(echo "$country" | sed -r 's/_/ /')
echo "Selected country : $test_country"
wan_interface=wlp1s0
wan_is_static=$false
logfile="/var/log/nordvpn/monitor.log"
connected=$false
mv $logfile $logfile.old

### FUNCTIONS
# Check for a connected WAN interface. works for wired and wireless alike.
# Will trap here in a loop until it sees a connection on the WAN interface.
# If previously connected and loses connection, will disconnect nordvpn.
# Always returns $true because it loops until it is $true.
check-wan() {
    if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] We are using $wan_interface for WAN. Checking connection..." | tee -a $logfile ; fi
    if ip -br a show $wan_interface | grep DOWN &> /dev/null ; then
        if [[ "$connected" == "$true" ]] ; then
            echo "[ $(date) ] WAN is DOWN!" | tee -a $logfile
            echo "[ $(date) ] Disconnecting NordVPN..." | tee -a $logfile
            nordvpn d &> /dev/null
            connected=$false
        fi
        echo "[ $(date) ] WAN is not connected: Waiting for connection..." | tee -a $logfile
        while ip -br a show $wan_interface | grep DOWN &> /dev/null ; do # if DOWN, traps until UP
            sleep 10
        done
        echo "[ $(date) ] WAN is connected" | tee -a $logfile
        while ! check-connectivity &> /dev/null ; do
            sleep 2 # give dhcp a chance to give an address on its own
            if [[ "$wan_is_static" == "$false" && "$(ip a show $wan_interface | grep UP)" && ! "$(ip a show $wan_interface | grep inet)" ]] ; then
                dhclient $wan_interface &> /dev/null # request an address
            fi
        done
        return $true
    elif ip -br a show $wan_interface | grep UP &> /dev/null ; then
        if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] WAN is connected" | tee -a $logfile ; fi
            return $true
    else
        echo "[ $(date) ] Unknown WAN state. Exiting..." | tee -a $logfile
            echo $(ip -br a show $wan_interface) | tee -a $logfile
            systemctl stop nordvpn-net-monitor.service
            exit 3
    fi
    return $true
}

# Check the connection status of nordvpn
# returns $true if nordvpn is connected
check-vpn() {
    vpn_status=$(nordvpn status)
        server=$(echo "$vpn_status" | grep Server)
    if [[ "$vpn_status" =~ "Connected" ]]; then
        if [[ "$vpn_status" =~ "$test_country" ]]; then
            if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] NordVPN is connected to preferred country: $test_country" | tee -a $logfile ; fi
            if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] NordVPN is connected to $server" | tee -a $logfile ; fi
                        return $true
        else
            return $false
        fi
    else
        return $false
    fi
}

# After <n> seconds we kill the connection request, pause 10 seconds, and try again.
# Each attempt should automatically try a different server.
# Eventually it will hit one that connects in seconds. Those are the ones we want.
# NordVPN is supposed to direct us to the fastest/nearest available server for us at any given time, but that doesn't always happen.
# Of course, this may be a side effect of using my phone to hotspot a wan connection while I wait for cable install.
connect-vpn() {
    while :; do
        echo "[ $(date) ] Connecting to NordVPN: $test_country" | tee -a $logfile
        exec 3< <(connect $country) # run connect attempt in background
        while read -r <&3 result ; do # read and process output from background
            echo -e "[ $(date) ] $result" | tee -a $logfile
            if [[ "$result" =~ "aborted" ]] ; then
                sleep 10 # waiting to try connect again
                check-wan
            elif [[ "$result" =~ "connected" ]] ; then
                echo "[ $(date) ] Successful connection to $(nordvpn status | grep Server)" | tee -a $logfile
                connected=$true
                return $true
            elif [[ "$result" =~ "does not exist" ]] ; then
                if [[ "$exit_on_bad_country_code" == "$true" ]] ; then
                    echo -e "[ $(date) ] Invalid country code specified: $country\n\tStopping nordvpn-net-monitor.service and exiting..." | tee -a $logfile
                    systemctl stop nordvpn-net-monitor.service
                    exit 4
                else
                    echo -e "[ $(date) ] Invalid country code specified: $country\n\tSetting to auto..." | tee -a $logfile
                    country=''
                    sleep 3
                fi
            fi
        done
    done
}

# connect() is only called as a background process by connect-vpn() and takes up to 1
# argument. It could easily support any nordvpn argument, but we only use it for country.
# A 'while read...' block in the calling function captures output from this function
# The actual connection to nordvpn happens here
connect() {
    nordvpn c $1 &
    npid=$!
    sleep 10 # connection timeout, how long to give nordvpn to connect
    if test -d /proc/$npid ; then # is 'nordvpn c' still alive
        if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] Killing 'nordvpn connect' attempt..." | tee -a $logfile ; fi
        while test -d /proc/$npid ; do
            pids=( $(pidof "nordvpn" &> /dev/null) )
            for pid in "$pids" ; do
                if [[ $pid =~ ^[0-9]+$ ]] ; then
                    echo "Killing PID : $pid"
                    kill "$pid"
                    if ! pidof "nordvpn" ; then
                        break
                    fi
                fi
            done
        done
        nordvpn d &> /dev/null
        echo "Connect aborted!"
    else
        : # you could add tasks here or after it connects
    fi
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
        echo "[ $(date) ] We have connectivity!" | tee -a $logfile
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
        systemctl stop nordvpn-net-monitor.service
        exit
    elif [[ "$nord_account" =~ "Account Information" ]] ; then
        echo "[ $(date) ] You are logged in to NordVPN!"
    else
        if [[ "$nordvpn status" =~ "Connected" ]] ; then
            nordvpn d # something went wrong. we shouldn't be connected at this point
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
        if check-vpn ; then
            echo "[ $(date) ] VPN is active." | tee -a $logfile
            sleep 10
            while check-wan ; do
                if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] WAN is connected" | tee -a $logfile ; fi
                if check-vpn ; then
                    if [[ "$verbose" == "$true" ]] ; then echo "[ $(date) ] VPN is active." | tee -a $logfile ; fi
                    sleep 10
                else
                    break # send it back to the outer loop
                fi
            done
        else
            connect-vpn
        fi
    done
}

### run the script:
# Initial check-wan(), cannot check account status if we don't have WAN connection
# check-wan() traps in a loop until it has WAN connection
# All logic is handled through the maintain() function after startup
check-wan
check-account-status

# babysit the connection
maintain
