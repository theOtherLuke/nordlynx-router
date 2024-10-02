#!/usr/bin/env bash

echo -e "\n\n"'\033[1;35m'"NordVPN router config file download script"'\033[0m'"\n\n"


wget -O /etc/iptables/rules.v4 https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/rules.v4
wget -O /etc/dnsmasq.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/dnsmasq.conf
wget -O /etc/sysctl.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/sysctl.conf
wget -O /etc/netplan/config.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config.yaml
wget -O /etc/netplan/config-wifi.yaml https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/config-files/config-wifi.yaml
