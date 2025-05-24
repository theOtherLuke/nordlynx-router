#!/usr/bin/env bash
echo $$ > /root/.monitor.pid
### constants
true=0
false=1

daemonized=$false
while getopts 'd' arg; do
    case $arg in
        d)
            daemonized=$true
            ;;
        *)
            echo "Unknown argument: ${arg}"
            exit 13
            ;;
    esac
done

## colors
[[ $daemonized == $true ]] && gn='' || gn='\e[0;32m'
[[ $daemonized == $true ]] && bu='' || bu='\e[0;34m'
[[ $daemonized == $true ]] && cy='' || cy='\e[0;36m'
[[ $daemonized == $true ]] && lt_gn='' || lt_gn='\e[1;32m'
[[ $daemonized == $true ]] && lt_yl='' || lt_yl='\e[1;33m'
[[ $daemonized == $true ]] && lt_bu='' || lt_bu='\e[1;34m'
[[ $daemonized == $true ]] && lt_cy='' || lt_cy='\e[1;36m'
[[ $daemonized == $true ]] && lt_rd='' || lt_rd='\e[1;31m'
[[ $daemonized == $true ]] && cl='' || cl='\e[0m'
a_color="${cl}"

## cursor options
[[ $daemonized == $true ]] && hide='' || hide='\e[?25l'
[[ $daemonized == $true ]] && show='' || show='\e[?25h'

[[ $daemonized == $true ]] &&

[[ $daemonized == $true ]] || echo -e "${hide}" # hide the cursor

license(){
    [[ $daemonized == $true ]] || echo -e "${lt_gn}"
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
    [[ $daemonized == $true ]] || echo -e "${cl}"
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
## I added the .conf file to simplify changing settings
source /root/connect-nord.conf


first_check=
if nordvpn status | grep Disconnected ; then 
    first_check=$false
else
    first_check=$true
fi

uptime_seconds=
uptime=

cleanup() {
    kill "${manager_pid}"
    echo -e "${show}${cl}" # restore the cursor
    rm /root/.monitor.pid &> /dev/null
    exit
}

trap cleanup INT SIGINT EXIT SIGTERM

check-connectivity() {
    # This method of checking connectivity seems to have trouble in multi-NAT situations
    # ping may be a better solution in those situations
    # if ping -c1 $test; then
    #     return $true
    # else
    #     return $false
    # fi
    test=google.com
    if nc -zw1 $test 443 && echo |openssl s_client -connect $test:443 2>&1 |awk '
    $1 == "SSL" && $2 == "handshake" { handshake = 1 }
    handshake && $1 == "Verification:" { ok = $2; exit }
    END { exit ok != "OK" }'; then
        if ping -c1 -W10 google.com &> /dev/null 2>&1; then
            return $true
        else
            return $false
        fi
    else
        return $false
    fi
}

while ! check-connectivity ; do
    wan_checks=0
    sysetmctl restart networking
    while ! ip -br a show ${wan} | grep UP ; do
        #((wan_checks++)) # comment this to wait for wan indefinitely
        echo -e "${lt_gn}Checking WAN. Attempt (${wan_checks})${cl}"
        if [[ $wan_checks -ge 10 ]] ; then
            echo "[ $(date) ] No active WAN connection after ${wan_checks} checks. Exiting script." | tee -a ${logfile}
            exit 2
        fi
        sleep 10
    done
done

get-uptime() {
    uptime=$(nordvpn status | grep Uptime)
    ## the rest of this function is only used for the auto-feedback if...elif...fi statement below
    declare -A uta
    read -s v1 k1 v2 k2 v3 k3 < <(IFS=":" read -s trash ut <<< $uptime && echo ${ut}) # separate time into keys and values,
                                                                                      # throw away the trash
    if [[ -n $k1 && -n $v1 ]] ; then
        uta[${k1}]="${v1}"
    fi
    if [[ -n $k2 && -n $v2 ]] ; then
        uta[${k2}]="${v2}"
    fi
    if [[ -n $k3 && -n $v3 ]] ; then
        uta[${k3}]="${v3}"
    fi
    uptime_seconds=$((uta[hours]*3600+uta[hour]*3600+uta[minutes]*60+uta[minute]*60+uta[seconds]+uta[second])) # add up the uptime in seconds
}

echo -e "${bu}LAN Interface :${lt_bu} ${lan}${cl}"
echo -e "${bu}WAN Interface :${lt_bu} ${wan}${cl}"
manage() {
    while :; do
        attempts=0
        time { # we're using time here to monitor how long NordVPN takes to connect
        while nordvpn status | grep Disconnected ; do
            ((attempts++))
            if ip -br a show ${lan} | grep UP ; then
                ip link set ${lan} down # I run multiple instances, which pfsense sees as multiple wans.
                                        # This disconnects the interface, otherwise pfsense doesn't recognize it as down and
                                        # won't fall back to another interface
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
            nordvpn c ${connect_options}
        done
        echo -e "\n\n${cy}Time elapsed :${cl}"
        }
        echo
        if [[ $first_check -eq $true ]] ; then
            echo -e "[ $(date) ]${lt_cy} Already connected!${cl}" | tee -a ${logfile}
            first_check=$false
        else
            echo -e "[ $(date) ]${bu} Connection established after${a_color} ${attempts}${bu} attempts.${cl}" | tee -a ${logfile}
        fi
        ip link set ${lan} up
        n_status=$(nordvpn status)
        server=$(grep Server <<< $n_status)
        [[ $daemonized == $true ]] && echo "[ $(date) ] $(grep Server <<< $n_status)" || echo -e "${gn}$(grep Server <<< $n_status)${cl}"
        [[ $daemonized == $true ]] && echo "[ $(date) ] $(grep Uptime <<< $n_status)" || echo -ne "${lt_gn}$(grep Uptime <<< $n_status)${cl}"
        while :; do
            ## test connection
            if ! check-connectivity ; then
                echo "[ $(date) ] Connection lost after ${uptime}" | tee -a ${logfile}
                ### this if...elif...fi section can be commented out or removed without issue
                ## this sends connection quality feedback to nordvpn using `nordvpn rate <n>` based on time
                ## the connection was active. I added this because I was having trouble staying connected
                ## and I figured they ought to know when their service is sucking.
                if [[ $uptime_seconds -lt 300 ]] ; then # less than 5 minutes
                    nordvpn rate 1
                elif [[ $uptime_seconds -ge 300 && $uptime_seconds -lt 900 ]] ; then # 5-15 minutes
                    nordvpn rate 2
                elif [[ $uptime_seconds -ge 900 && $uptime_seconds -lt 1800 ]] ; then # 15-30 minutes
                    nordvpn rate 3
                elif [[ $uptime_seconds -ge 1800 ]] ; then # 30 minutes or more
                    nordvpn rate 4
                fi # I didn't put an entry for 5 because only 100% stable and reliable connections should be
                   # rated 5. If it disconnects without my intervention, it's not a 5
                nordvpn d
                break
            fi
            sleep 10
            get-uptime
            [[ $daemonized == $true ]] && echo "[ $(date) ] ${server}" # || echo -ne "${gn}\r${server}${cy}${cl}\e[K"
            [[ $daemonized == $true ]] && echo "[ $(date) ] ${uptime}" || echo -ne "${lt_gn}\r${uptime}${cy}${cl}\e[K"
            if ip -br a show ${lan} | grep DOWN ; then
                ip link set ${lan} up
            fi
        done
    done
}

trap-keyboard() {
    while :; do
        read -srn1 result
        result="${result,,}"
        case "$result" in
            q)
                echo
                echo "Exiting..."
                exit
                ;;
            *) ;;
        esac
    done
}

if [[ $daemonized == $false ]]; then
    manage & manager_pid="$!"
    trap-keyboard
else
    manage
fi
