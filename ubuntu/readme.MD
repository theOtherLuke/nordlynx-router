# Ubuntu Specific Setup Steps

## COMING SOON!!

> [!CAUTION]
> This is a *rough* draft of the steps. While it may work, I have not fully tested it yet.
> These are simply the steps without too much description.

** The biggest differences between this and the debian version is the use of kea-dhcp and netplan instead of dnsmasq and ifupdown**

## Steps

Create Ubuntu container - minimums: 1 core, 128m, 128m swap, 4GB drive, 2 network interfaces

WAN - dhcp, set dns-server under dns section of container in proxmox

LAN - static, no address or gateway


`apt update && apt upgrade -y && apt remove ufw -y && apt install iptables-persistent curl -y`

**Setup kea dhcp server** 

steps taken from: https://www.techtutorials.tv/sections/linux/how-to-install-and-configure-kea-dhcp-server/

`curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-2-2/setup.deb.sh' | bash`

configure kea-dhcp

`nano /etc/kea/kea-dhcp4.conf`

paste settings from attached file, adapt to your needs, save and exit

**enable forwarding**

`nano /etc/sysctl.conf`

uncomment `#net.ipv4.ip_forward=1`

you can disable ipv6 using the method in the main writeup


**Cofigure network**

Ubuntu uses netplan

set WAN (eth0) to dhcp, set only the address for LAN (eth1)

`nano /etc/netplan/config.yaml`

paste settings from attached file, adapt to your needs, save and exit

`netplan apply`


**Setup iptables rules**

remember, eth1 is LAN, nordlynx is WAN

```
iptables -t nat -A POSTROUTING -o nordlynx -j MASQUERADE
iptables -A FORWARD -i eth1 -o nordlynx -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o nordlynx -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```


**Setup nordvpn**

this is the same process as the main write up

`sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)`

login:

`nordvpn login`

copy link, past into browser, login, copy link from browser, paste into this command:

`nordvpn login --callback "<link>"`

don't forget the double quotes

set nordvpn settings:

routing needs to be enabled

`nordvpn set routing on`

turn on autoconnect:

`nordvpn set autoconnect on`

connect to nordvpn:

`nordvpn c`

test and enjoy
