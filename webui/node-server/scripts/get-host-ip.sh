#!/usr/bin/env bash

# check which network daemon we are using and return the configured ipv4 for the lan
if [[ -f /etc/netplan/config-lan.yaml ]] && which netplan &>/dev/null; then
    # check for yq and install if missing
    which yq $> /dev/null || apt install yq -y $> /dev/null
    # Extract the first static IP from the Netplan config
    yq -r '.network.ethernets | to_entries[] | .value.addresses[0]' /etc/netplan/config-lan.yaml | cut -d'/' -f1
else
    DNSMASQ_CONF="/etc/dnsmasq.conf"
    INTERFACES="/etc/network/interfaces"
    
    # Get the LAN interface from dnsmasq
    iface=$(
        awk -F= '
            /^[[:space:]]*interface=/ {
                gsub(/[[:space:]]/, "", $2)
                print $2
                exit
            }
        ' "$DNSMASQ_CONF"
    )
    
    [[ -n "$iface" ]] || exit 1
    
    # Find its configured address and strip the CIDR suffix
    awk -v iface="$iface" '
        $1 == "iface" && $2 == iface {
            in_iface = 1
            next
        }
    
        $1 == "iface" {
            in_iface = 0
        }
    
        in_iface && $1 == "address" {
            split($2, ip, "/")
            print ip[1]
            exit
        }
    ' "$INTERFACES"
fi
