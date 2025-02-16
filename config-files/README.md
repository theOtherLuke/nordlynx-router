# config files
File locations assume Debian/Ubuntu as you distro.

### config-dhcp.yaml
Used for dhcp lan connections.

Edit and place in `/etc/netplan/`

### config-static.yaml
Used for static or manual lan connections

Edit and place in `/etc/netplan/`

### config-wifi.yaml
Used for WiFi connections. At the moment this only works as dhcp. I have no plans to create a wireless AP version of this. You can set this as static by replacing `dhcp4: true` with a static address.
```
# remove
dhcp4: true

# replace with
addresses:
- <ipaddress>/24
```

Edit and place in `/etc/netplan/`

### dnsmasq.conf
Config file for dnsmasq.

Edit and place in `/etc/`

### sysctl.conf
Enable ipv4 forwarding and optionally disable ipv6 here. Disabling ipv6 does not work with wpa-supplicant.

Edit and place in `/etc/`

### rules.v4
Firewall rules for iptables. All 3 `mgmt_interface` rules may be removed without issue.

Edit and place in `/etc/iptables/`
