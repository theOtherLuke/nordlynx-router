# a simple function to extract interface names and ip address and display them at the start of the shell
# and since this is a .bashcr function, you can call it from the cli
show-interface-info() {
    length=0
    declare -A ifaces
    declare -A iface_addrs
    while IFS="=" read -r key value; do
        iface_addrs["$key"]="$value"
        if [[ ${#key} -gt $length ]]; then
            length=${#key}
        fi
    done < <(ip -j -4 a | jq -r '
      map(select(.ifname != "lo"))
      | map({ (.ifname): (.addr_info[]?.local) })
      | add
      | to_entries[]
      | "\(.key)=\(.value)"
    ')
    for key in "${!iface_addrs[@]}"; do
        ifaces["$key"]="${iface_addrs[$key]}"
    done
    ((length++))
    echo
    for interface in "${!ifaces[@]}"; do
        address="${ifaces[$interface]}"
        echo -e "\e[1;32m${interface}\e[${length}G\e[0m : \e[1;36m${address}\e[0m"
    done
    echo
    if [[ -d /root/webui ]]; then
        next=0
            while read -r line; do
                if [[ $line =~ (address) ]]; then
                    next=1
                elif [[ $next -eq 1 ]]; then
                    address=${line#*- }
                    address=${address%%/*}
                fi
            done < <(cat /etc/netplan/config-lan.yaml)
        echo -e "\e[1;35mAccess the webui at: \e[1;36mhttps://${address}:1776\e[0m\n"
        export WEBUI_IP="$address"
    fi
    echo
}
clear

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
show-interface-info
