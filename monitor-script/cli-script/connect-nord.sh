#!/usr/bin/env bash

echo -e '\e[?25l' # hide the cursor

license(){
    echo -e '\e[1;32m'
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
    echo -e '\e[0m'
}

clear && license && sleep 1

header(){
        cat <<EOF

        _   _               ___     ______  _   _
       | \ | | ___  _ __ __| \ \   / /  _ \| \ | |
       |  \| |/ _ \| '__/ _  |\ \ / /| |_) |  \| |
       | |\  | (_) | | | (_| | \ V / |  __/| |\  |
       |_| \_|\___/|_|  \__,_|  \_/  |_|   |_| \_|

              ____             _
             |  _ \ ___  _   _| |_ ___ _ __
             | |_) / _ \| | | | __/ _ \ '__|
             |  _ < (_) | |_| | ||  __/ |
             |_| \_\___/ \__,_|\__\___|_|

    Whole-network VPN router using the NordVPN Service

EOF
}
clear && header

### options
## lan, wan, logfile, and connect_options are defined in connect-nord.conf. define your settings there
## or comment the source call and uncomment lan, wan, logfile, and connect_options to define them here
## I added the .conf file to simplify changing settings
source ./connect-nord.conf
#lan=eth21
#wan=eth0
#logfile="/var/log/nordvpn/monitor.log"
#connect_options="us"

### constants
true=0
false=1

## colors
gn='\e[0;32m'
lt_gn='\e[1;32m'
lt_yl='\e[1;33m'
lt_rd='\e[1;31m'
cl='\e[0m'

a_color='\e[0m'

cleanup() {
    echo -e '\e[?25h' # restore the cursor
    exit
}

trap cleanup INT SIGINT EXIT SIGTERM

check-connectivity() {
    test=google.com
    if nc -zw1 $test 443 && echo |openssl s_client -connect $test:443 2>&1 |awk '
    $1 == "SSL" && $2 == "handshake" { handshake = 1 }
    handshake && $1 == "Verification:" { ok = $2; exit }
    END { exit ok != "OK" }'; then
        return $true
    else
        return $false
    fi
}

while ! check-connectivity ; do
    wan_checks=1
    while ! ip -br a show ${wan} | grep UP ; do
        echo -e "${lt_gn}Checking WAN. Attempt (${wan_checks})${cl}"
        if [[ $wan_checks -ge 10 ]] ; then
            echo "[ $(date) ] No active WAN connection after ${wan_checks} checks. Exiting script." | tee -a ${logfile}
            exit 2
        fi
        sleep 10
    done
done

echo -e "${gn}LAN Interface :${lt_gn} ${lan}${cl}"
echo -e "${gn}WAN Interface :${lt_gn} ${wan}${cl}"
while :; do
    attempts=1
    time while nordvpn status | grep Disconnected ; do
        if ip -br a show ${lan} | grep UP ; then
            ip link set ${lan} down # I run multiple instances, which pfsense sees as multiple wans. This disconnects the interface, otherwise pfsense doesn't recognise it as down.
        fi
        ## change the color of the attempt counter based on number of connection attempts
        if [[ ${attempts} -lt 10 ]] ; then
            a_color="${lt_gn}"
        elif [[ ${attempts} -ge 10 && ${attempts} -lt 20 ]] ; then
            a_color="${lt_yl}"
        elif [[ ${attempts} -ge 20 ]] ; then
            a_color="${lt_rd}"
        fi
        echo -e "Attempt${a_color} [ ${attempts} ]${cl}"
        nordvpn c "${connect_options}" ; ((attempts++))
    done
    echo -e "[ $(date) ] Connection established after${a_color} ${attempts}${cl} attempts." | tee -a ${logfile}
    ip link set dev ${lan} up
    n_status=$(nordvpn status)
    echo -e "\e[0;32m$(grep Server <<< $n_status)\e[0m"
    echo -ne "\e[1;32m$(grep Uptime <<< $n_status)\e[0m"
    while nordvpn status | grep Server &> /dev/null ; do
        ## test connection
        if ! check-connectivity ; then
            echo "[ $(date) ] Connection lost." | tee -a ${logfile}
            nordvpn d
            break
        fi
        sleep 10
        echo -ne "${lt_gn}$(nordvpn status | grep Uptime)${cl}\e[K"
        if ip -br a show ${lan} | grep DOWN ; then
            ip link set ${lan} up
        fi
    done
done
