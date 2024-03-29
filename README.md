# nordlynx-router
Instructions for creating a NordVPN router on any NordVPN supported linux distro using the nordlynx protocol.

As with all of my work, ymmv.

This is the sequence of steps I take to setup my NordVPNP router vm using Debian 12 as the host os. I am working on a bash script to automate as much of this as possible, but that script is not a high priority right now. If/when I complete it, I will add it to this project.

Can you use a different distro? Probably. I'm sure these steps can be adapted to any distro on which the official nordvpn app can be installed.

Which nordvpn protocols or options can you use? You can use any protocol or option available in the nordvpn app.


At some point I will upload some config files for you to use. For now I encourage you to take this opportunity to learn the process.



## TL:DR

Start with a fresh Debian 12 install

Connect the WAN interface. Configure as dhcp

Install additional packages
  $ apt install iptables-persistent dnsmasq dnsmasq-utils

Install NordVPN following instructions here:
    https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions

Login to NordVPN following instructions here:
    https://support.nordvpn.com/hc/en-us/articles/20226600447633-How-to-log-in-to-NordVPN-on-Linux-devices-without-a-GUI

Connect and configure the LAN interface as static without gateway.

Add iptables rules and save.

Configure DHCP server.

Enable forwarding.

Test

Enjoy


## Instructions

# What do you need
  1. HOST - A host machine, vm, or container with at least 1 core, 512M RAM, 8G drive space, and 2 network intefaces.
  2. CLIENT - A client machine for testing. This can be any internet capable device that can be connected to the second network interface on the host.
  3. An internet connection that can be connected to the primary network interface in the host.

# So, here we go:

While conducting your install, test connnectivity at EVERY step. Sometimes this will be on the host. Sometimes this will be on a client. I generlly use ping for most of this, then add a browser to the test toward the end. If at any point you lose internet connectivity, stop and diagnose it then. This will make it easier to track down the issue. I will add some troubleshooting tips I came up with at the end of this writeup.


Step 1:

Start with a fresh install of Debian 12, fully updated. For now, only connect the internet facing interface, which will be referred to as wan. If installing on bare metal, or any other method that would hinder copy/paste functionality, I recommend configuring over ssh so you can copy and paste.

If you want to use ssh to configure NordVPN, configure it on the host:

if you don't have an ssh server installed (Debian allows you to select it at install):
$ apt install openssh-server
    
Allow login with password (unless you want to use keys, which you will need to figure that out yourself. Sorry)
$ nano /etc/ssh/sshd_config
    
Uncomment the line that say PermitLoginWith password and change it to say 'PermitLoginWithPassword yes'
  
Test internet connetivity on host.


Step 2:

Install extra packages:
$ sudo apt update
$ sudo apt install iptables-persistent dnsmasq dnsmasq-utils
Test internet connetivity on host.


Step 3:

Install official NordVPN linux app. These are the commands from the official NordVPN website:
using curl - 
$ sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

using wget - (I prefer this over additionally installing curl)
$ sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)

Login to nordvpn:
note: the linux without gui login instructions can be found at :
https://support.nordvpn.com/hc/en-us/articles/20226600447633-How-to-log-in-to-NordVPN-on-Linux-devices-without-a-GUI
    
This command will produce a url to get the key:
$ nordvpn login

Copy the url and paste it into a browser.
    
Cancel the request to open an external link.
    
Right-click the "Continue" button and copy the link.
    
Back in the host terminal/ssh, paste the link into this command : ( don't forget to add the double quote around the url )
$ nordvpn login --callback "<link from Continue button>"

You should receive a message on that you have logged in.

Configure your nordvpn settings:
$ nordvpn set ...
A list of settings can be found here : https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions
Do not enable killswitch or autoconnect yet

Test internet connetivity on host.


Step 4:

Connect/configure LAN interface:
$ nano /etc/network/interfaces

example -
    
auto lo
iface lo inet loopback

auto enp6s18
iface enp6s18 inet dhcp

auto enp6s19
iface enp6s19 inet static
        address 192.168.123.1/24 # this will be the subnet for your LAN

Do not configure a gateway. The gateway is configured on WAN through dhcp.

Test internet connetivity on host.


Step 5:

Configure iptables rules to allow LAN traffic to use th vpn connection.
In addition to normal forwarding and nat rules, we need to add a rule to mark LAN connections so nordvpn allows them through the firewall.
Make sure nord vpn is not connected and killswitch is off before saving your rules:
$ nordvpn d && nordvpn killswitch off

Confirm no nordvpn rules are active:
$ iptables -L
Look for entries that say nordvpn

Add iptables rules and save:
$ iptables -t mangle -A PREROUTING -i enp6s19 -j CONNMARK --set-mark 0xe1f1 -m comment --comment nordvpn
$ iptables -t nat -A POSTROUTING -o nordlynx -j MASQUERADE
$ iptables -A FORWARD -i enp6s19 -o nordlynx -j ACCEPT
$ iptables-save > /etc/iptables/rules.v4

Test internet connetivity on host.


Step 6:

Configure DHCP server on the LAN:
$ nano /etc/dnsmasq.conf
  
Uncomment '#interface=' and assign to your LAN interface:
interface=enp6s19
 
Uncomment 'dhcp-range=.....' and adjust to your subnet, range, and lease time:
dhcp-range=192.168.55.50,192.168.55.100,12h
  
Save and exit.
  
Test internet connetivity on host.


Step 7:

Enable ipv4 forwarding:
$ nano /etc/sysctl.conf
    
Uncomment 'inet.ipv4.ip_forward=1'
      
If you want to disable ipv6 add the following to the end of the file:
# Disabling ipv6 :
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

Save and exit.

Test internet connetivity on host.


Step 8:

Enable killswitch and autoconnect:
$ nordvpn set killswitch on
$ nordvpn set autoconnect on

Step 9:

If all went well, you are done.

ENJOY!


## TIPS

These tips should be helpful for others like me who suffer from imanidiot syndrome flareups 80

If you can ping the WAN interface on the vpn but not beyond (WAN,internet,etc) from a client on the LAN
1. open /etc/sysctl.conf and make sure you have enabled net.ipv4.ip_forward=1
I personally have been guilty of going too fast and not reading, which caused me to uncomment the wrong ipv4 line
I actually did that following and editing this
2. inspect your iptables rules on the vpn lxc/vm/machine
for NordVPN, you should have 3 rules in your /etc/iptables/rules.v4 file. Double check your work in STEP 5.

If you can ping an ip address but not a domain name
1. check your DNS settings on the VPN. Double check your work up to STEP 3.
