# Ubuntu Specific Setup Steps

## WORK-IN-PROGRESS

> [!CAUTION]
> This is a *rough* draft of the steps. While it may work, I have not fully tested it yet.
> These are simply the steps without too much description.

**The biggest differences between this and the debian version is the use of kea-dhcp and netplan instead of dnsmasq and ifupdown + net-tools**

I may change the debian version to use netplan and kea to make this more universal with fedora and ubuntu

## Steps

Create Ubuntu container - minimums: 1 core, 128m, 128m swap, 4GB drive, 2 network interfaces

*I workshopped this using 23.10 because that is the version from issue #3. However, 23.10 is end of life and users are strongly encouraged to update to 24.04. I have updatetd to 24.04 and have seen no issues. Just make sure you don't let a distro upgrade overwrite your config files*

WAN - dhcp, set dns-server under dns section of container in proxmox

LAN - static, no address or gateway


`apt update && apt upgrade -y && apt remove ufw -y && apt install iptables-persistent -y`

**Setup kea-dhcp server** - *kea-dhcp4-server is the replacement for isc-dhcp-server* - *isc-dhcp-server is end-of-life*

install kea-dhcp4-server from ubuntu repo:

`apt install kea-dhcp4-server -y`

configure kea-dhcp

`nano /etc/kea/kea-dhcp4.conf`

paste settings from attached file, adapt to your needs, save and exit

**enable forwarding**

`nano /etc/sysctl.conf`

uncomment `#net.ipv4.ip_forward=1`

you can disable ipv6 using the method in the main writeup


**Cofigure network**

set WAN (eth0) to dhcp, set only the address for LAN (eth1)

`nano /etc/netplan/config.yaml`

paste settings from attached file, adapt to your needs, save and exit

`netplan apply`

You may get an error when running the apply. Simply reboot and the settings should have taken.

**Setup iptables rules**

remember, eth1 is LAN, nordlynx is WAN

> [!TIP]
> To test if forwarding is working without nordvpn, change nordlynx to your wan interface and test on a client before installing/starting nordvpn

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
