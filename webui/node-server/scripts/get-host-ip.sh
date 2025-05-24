#!/usr/bin/env bash
# check for yq and install if missing
which yq $> /dev/null || apt install yq -y $> /dev/null
# Extract the first static IP from the Netplan config
yq -r '.network.ethernets | to_entries[] | .value.addresses[0]' /etc/netplan/config-lan.yaml | cut -d'/' -f1
