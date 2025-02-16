# nordlynx-router - Debian Edition

Instructions for creating a NordVPN router on Debian 12 using the nordlynx protocol.


As with all of my work, ***YMMV***.

This is the sequence of steps I take to setup my NordVPN router vm using Debian 12 as the host os. I am working on a bash script to automate as much of this as possible, but that script is not a high priority right now. If/when I complete it, I will add it to this project.



Can you use a different distro? *Sort of*. I'm sure these steps can be adapted to any distro on which the official nordvpn app can be installed.

Which nordvpn protocols or options can you use? You should be able to use any protocol or option available in the nordvpn app. Killswitch is always enabled for LAN traffic, but can be disabled for WAN for the host.

I have uploaded a service I created to manage this connection. Follow the readme in the 'monitor-script' folder for instructions.

Although I have uploaded some config files, I encourage you to follow and learn the process for yourself.


If anyone figures out how to use meshnet using this vm/lxc etc., I would welcome the input. Currently, I am using a docker/wireguard instance to connect from outside. I will be working on it myself, but like the install script, that is a low priority.



## TL;DR

Start with a fresh Debian 12 install

Add a second network interface. This can be another lan or even wifi device. Wifi is easy on a vm, just passthrough the wifi adapter. It's more complicated for LXCs.

Configure network interfaces. WAN as dhcp, LAN as static and assign address

Install additional packages
  `$ sudo apt install iptables-persistent dnsmasq dnsmasq-utils sudo -y`

Install NordVPN following instructions here:

https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions

Login to NordVPN following instructions here:

https://support.nordvpn.com/hc/en-us/articles/20226600447633-How-to-log-in-to-NordVPN-on-Linux-devices-without-a-GUI

Add iptables rules and save. Use `nordlynx` as the WAN interface in iptables

Configure dnsmasq.

Enable forwarding in `/etc/dnsmasq.conf`

Test

Enjoy


# Instructions

## What do you need?
  1. HOST - A host machine, vm, or container with at least 1 core, 128M RAM, 4G drive space, and 2 network intefaces for an lxc. *A vm or bare metal may require more. This requires testing.* This will become the VPN router.
  2. CLIENT - A client machine for testing. This can be any internet capable device that can be connected to the second network interface on the host.
  3. An internet connection that can be connected to the primary network interface in the host.

## So, here we go:

While conducting your install, **test connnectivity at _EVERY_ step**. Sometimes this will be on the host. Sometimes this will be on a client. I generally use ping for most of this, then add a browser to the test toward the end. If at any point you lose internet connectivity, stop and diagnose it at that point. This will make it easier to track down the issue. I will add some troubleshooting tips I came up with at the end of this writeup.

This guide assumes you are eoing this on a clean install with no added iptables rules.


**Step 1:**

Start with a fresh install of Debian 12, fully updated. If installing on bare metal, or any other method that would hinder copy/paste functionality, I recommend configuring over ssh so you can copy and paste.

Make sure the user you use to set this up is in sudoers `usermod -aG sudo $USER`.

You may need to install sudo `apt install sudo`

If you want to use ssh to configure, make sure you have an ssh server installed. If you don't have an ssh server installed you can install one now:

`$ sudo apt install openssh-server`
    

Test internet connectivity on host.


**Step 2:**

Install extra packages:
```
$ sudo apt update
$ sudo apt install iptables-persistent dnsmasq dnsmasq-utils -y
```
Test internet connetivity on host.


**Step 3:**

Install the official NordVPN linux app. These are the commands from the official NordVPN website:

`$ sudo sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)`

Login to nordvpn:

note: the linux without gui login instructions can be found at :

https://support.nordvpn.com/hc/en-us/articles/20226600447633-How-to-log-in-to-NordVPN-on-Linux-devices-without-a-GUI
    
Enter this command to produce a url to get the key:

`$ nordvpn login`

Copy the url and paste it into a browser.
    
Cancel any request to open an external link.
    
Right-click the "Continue" button and copy the link.
    
On the host terminal/ssh, paste the link into this command : (don't forget to add the double quote around the url )

`$ nordvpn login --callback "<link from Continue button>"`

You should receive a message that you have logged in.

Configure your nordvpn settings:

`$ nordvpn set ...`

My testing suggests routing needs to be enabled:

`nordvpn set routing on`

In some cases it seems lan-discoery also needs to be enabled:

`nordvpn set lan-discovery on`


A list of settings can be found here : https://support.nordvpn.com/hc/en-us/articles/20196094470929-Installing-NordVPN-on-Linux-distributions

Do not enable autoconnect yet

_If you plan to configure over wan using ssh, be sure to whitelist port 22_

`$ nordvpn whitelist add port 22`

_...and for security, remove port 22 when you are done_

`$ nordvpn whitelist remove port 22`

Test internet connectivity on host.


**Step 4:**

Connect/configure LAN interface:

`$ sudo nano /etc/network/interfaces`

example -
```
# localhost
auto lo
iface lo inet loopback

# WAN
auto enp6s18
iface enp6s18 inet dhcp

# LAN
allow-hotplug enp6s19
iface enp6s19 inet static
        address 192.168.123.1/24 # this will be the subnet for your LAN
# if installing as an lxc on Proxmox, configure the LAN address here, not on the host.
```

Do not configure a gateway. The gateway is configured on WAN through dhcp.

Test internet connectivity on host.

Configure iptables rules to allow LAN traffic to use the vpn connection. The trick is assigning nordlynx as the WAN interface.

Easy way:
download rules.v4 (above) and place in your /etc/iptables/ directory

Educational way:

`$ nano /etc/iptables/rules.v4`


Add the following:
```
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i enp6s18 -m comment --comment nord-router -j CONNMARK --set-xmark 0xe1f1/0xffffffff
COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i eth1 -o nordlynx -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i eth1 -o nordlynx -j ACCEPT
COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o nordlynx -j MASQUERADE
COMMIT
```

Press `ctrl-x`, `y`, and press `enter` to save and exit.

I am not entirely certain the mangle rule is needed. recent testing shows NordVPN adding DROP rules to the FORWARD section of the filter table. The mangle rule marks our traffic so it is allowed to pass and not get dropped by nord's rules.
The FORWARD traffic is being directed through the nordlynx interface, which ceases to pass traffic any time nordvpn disconnects, regardless of killswitch state. If you want to be able to pass traffic while nordvpn is down, you need to add FORWARD rules using your wan interface instead of the nordlynx interface. I don't have a clue how to do that with iptables without using a script that monitors the nordvpn state and dynamically adds/removes those rules when the vpn goes down/up depending on if killswitch is enabled, if that's even possible. I have no interest in disabling the killswitch, so I'm not planning on writing such a script.

```
In this rough diagram traffic travels clockwise:

                    PREROUTING - INPUT
                   /     |           \
NETWORK INTERFACES    FORWARD         LOCALHOST
                   \     |           /
                   POSTROUTINNG - OUTPUT
```

Test internet connectivity on host.


**Step 6:**

Configure DHCP server on the LAN:

`$ nano /etc/dnsmasq.conf`
  
Uncomment '#interface=' and assign to your LAN interface:

`interface=enp6s19`

Uncomment 'dhcp-range=.....' and adjust to your subnet, range, and lease time:

`dhcp-range=192.168.55.50,192.168.55.100,12h`

The dhcp-range should match the LAN subnet. 

Save and exit.
  
Test internet connectivity on host.

Check the client to make sure it is being assigned an ip address. Even though you won't have internet access from the client yet, it should be assigned an ip address at this point. 

`$ ip a`

Look for your lan interface and verify it has an address on your subnet(dhcp-range). If not, you may need to whitelist ports 67 and maybe 68 for dnsmasq to work. I haven't needed this on any of my setups this far though. Thank you @Kenny606 for this tidbit.

server port:

`$ nordvpn whitelist add port 67`

client port: (if still broken after whitelist port 67)

`$ nordvpn whitelist add port 68`


**Step 7:**

Enable ipv4 forwarding:

`$ nano /etc/sysctl.conf`

Uncomment 'inet.ipv4.ip_forward=1'
      
If you want to disable ipv6 add the following to the end of the file:
```
# Disable ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

Save and exit.

Test internet connectivity on host and client.


**Step 8:**

Enable autoconnect:

`$ nordvpn set autoconnect on`

At this point you can see how the killswitch works by disconnecting the vpn `$ nordvpn d` and then testing on a client.


**Step 9:**

If all went well, you are done.

ENJOY!

***UPDATE 2024-08-17:***
## SIMPLIFIED OUTLINE OF MY SETUP

N100 based SFF with 4 i226 2.5Gb ethernet ports running Proxmox. I have a N5105 based SFF with 6x i225 2.5Gb ports as a backup. Both are configured the same.

Ports are assigned to virtual bridges (vmbr0..n) as follows:

1 port to vmbr1 -
      This is the WAN connection. The physical port assigned to this bridge is connected directly to my ISP router/modem. Any vm or lxc that needs direct access to my ISP router/modem will connect by assigning vmbr1 as a network port in the vm/lxc. For security, this vmbr has no direct connection to the LAN.

3 ports to vmbr0 -
      This is the LAN connection. This is connected inside Proxmox to the LAN side of my pfsense vm. ALL of my LAN traffic passes through pfsense. I connect to my wired network and wifi router using the physical ports passed to vmbr0. This is also where my Proxmox management interface connects.

I have 2 lxc containers running nordvpn. One only connects to nordvpn p2p servers. My torrent server only connects through this vpn using pfsense routing rules. The other vpn connects to non-p2p servers and handles the rest of my traffic. The WAN for both of these is assigned to vmbr1, the WAN bridge. The LAN for each is assigned to their respective bridge in Proxmox to facilitate connecting to pfsense. Each one provides its own LAN DHCP with limited address pools on different subnets. For example vpn1 might be 10.1.1.0/24 while vpn2 might be 192.168.77.0/24. I could just do static assignments, but DHCP makes it easier if I need to connect directly to one of them for troubleshooting. 

I use additional virtual bridges to internally "wire" the vpns to pfsense. vmbr2 would be main traffic to WAN1, vmbr3 would be WAN2 for p2p.

pfsense is configured for multi WAN and firewall/NAT rules pass traffic to the proper WAN. pfsense also provides DHCP for the LAN side network.

I also have vmbr1 connected directly to pfsense as a 3rd WAN that only handles traffic to my wireguard instance for access from outside, again routed using firewall/NAT/port-forwarding rules, but that is beyond the scope of this writeup. This is so I can access the LAN even of nord is down. That way I can fix nord related issues from abroad if needed.

```
   ROUTER/MODEM
        |
      vmbr1
   /    |    \
vpn1   vpn2   |--WIREGUARD
  |     |     |
vmbr2  vmbr3  |
   \    |    /
     pfsense
       |
     vmbr0
       |
      LAN
```



## TIPS

These tips should be helpful for others like me who suffer from imanidiot syndrome flareups

If you can ping the LAN interface on the vpn but not beyond (WAN,internet,etc) from a client on the LAN:
1. open /etc/sysctl.conf and make sure you have umcommented/enabled net.ipv4.ip_forward=1
I personally have been guilty of going too fast and not reading, which caused me to uncomment the wrong ipv4 line.
I actually did that while following and editing this.
2. inspect your iptables rules on the vpn lxc/vm/machine, you should have 3 rules in your /etc/iptables/rules.v4 file. Double check your work in STEP 5.

If you can ping an ip address but not a domain name:
1. check your DNS settings. Double check your work up to STEP 3.
