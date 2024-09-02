# Debian Specific Setup Steps

See 'old-version.txt' for original version

**This is the "latest and greatest" version of the project**

## Start with a fresh Debian 12 install. I use lxc containers on Proxmox. VM or bare metal shoul be similar.

Machine recommendations:

1 core

128MB RAM ( I have succeeded with as little as 96MB, but normally just leave the Proxmox default of 512MB )

128MB swap ( My testing does not show that swap is even being used, so may possibly be excluded. Normally I just leave the Proxmox default of 512MB )

4GB drive ( 2GB minimum )

2 network interfaces ( 1 interface minimum )

Update Debian:

`apt update && apt upgrade -y`

### This way is recommended way if you want to learn how it goes together

Update Debian and install packages:

```
apt update
apt upgrade -y
apt install iptables-persistent dnsmasq dnsmaq-utils netplan.io -y
```

You could install unbound or some other dns resolver here as well. I use my pihole instance

**Configure settings**

***enable forwarding***

`nano /etc/sysctl.conf`

and uncomment `#inet.ipv4.ip_forward=1`

***iptables***

```
# clear tables
iptables -t filter --flush
iptables -t nat --flush
# add forwarding rules
iptables -t nat -A POSTROUTING -o nordlynx -j MASQUERADE
iptables -A FORWARD -i enp6s19 -o nordlynx -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp6s19 -o nordlynx -j ACCEPT
# save the rules
iptables-save > /etc/iptables/rules.v4
```

You can test forwarding before installing nordvpn by replacing nordlynx with your wan interface. This is a good way to avoid wasted troubleshooting time later.

***Configure the network***

Edit the network configuration file

`nano /etc/netplan/config.yaml`

You *must* use spaces in this file, not tabs.

```
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses:
      - <lan_address>/24
```

Replace <lan_interface> with your host's lan facing ip address.

***Configure the dhcp server***

Edit the dnsmasq config file

`nano /etc/dnsmasq.conf`

```
## LAN facing interface ##
interface=eth1

## address pool for dhcp, and lease time ##
dhcp-range=10.1.1.2,10.1.1.20,1h
```

***Before installing NordVPN, I recommend testing forwarding using the instructions in the iptables section above before continuing***
*This setup should pass traffic from a client without NordVPN installed. Everything up to this point is just how to setup a basic router. The last step is what makes it a NordVPN router.*

***Make it go***

*Install the NordVPN package*

Install NordVPN following instructions here:

https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions

`sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)`

Login to nordvpn: note: the linux without gui login instructions can be found at :

https://support.nordvpn.com/hc/en-us/articles/20226600447633-How-to-log-in-to-NordVPN-on-Linux-devices-without-a-GUI

`nordvpn login`

Copy the url and paste it into a browser.

Cancel the request to open an external link.

Right-click the "Continue" button and copy the link.

On the host terminal/ssh, paste the link into this command : (don't forget to add the double quote around the url )

`nordvpn login --callback "<link from Continue button>"`

You should receive a message that you have logged in.

Configure your nordvpn settings:

`nordvpn set ...`

My testing suggests routing needs to be enabled:

`nordvpn set routing on`

A list of settings can be found here : https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions

***Connect and enjoy***
