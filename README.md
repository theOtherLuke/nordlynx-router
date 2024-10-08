# Linux based NordVPN router

## ***Many apologies for any chaos or confusion. Sometimes I get excited and share before ready. These scripts are not yet polished and 100% reliable yet. Use at your own risk. I suggest following the write-up in the debian folder. Replace the network configuration with what works for you. Or break down the script and follow the steps or even write your own.***

**I created this to help others build and configure their own whole-network router using NordVPN**

The idea is to be able to use the native linux app for NordVPN to create a whole-network vpn router. So far I have been able to get this working on Ubuntu, Debian, Fedora, CentOS, and AlmaLinux. Every version of the install has the same packages being used for portability between distros.

***They all use these packages:***

*Network configuration:*  netplan.io

*Firewall configuration:*  iptables-persistent or iptables-services - same package, different name depending on distro

*dhcp server:*  dnsmasq + dnsmasq-utils

Use the script below or follow the instructions in the appropriate folder in this repository.

## System recommended minimums for lxc containers

1 core

4GB drive

128MB RAM

128MB swap

2 network interfaces

Ubuntu and Fedora require dns server address to be manually configured. I set it in the container settings in Proxmox

## Debian, Ubuntu, Fedora, CentOS, AlmaLinux
I have not compared the on-disk or backup sizes of each of these.

*See debian/old-version.txt for original writeup*

**Run the install script**
> [!WARNING]
> The script is not production ready. I advise you to use it for reference only. When the new script is ready, I will update these links.

Using wget: *Debian, Ubuntu*

`bash <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/setup-nord-router.sh)`

Using curl: *Fedora,CentOS,AlmaLinux*

Be forewarned, CentOS and AlmaLinux are a significantly slower install process due to needing to add repos and the oddly slow speed of dnf operations on these distros. Interestingly, the nordvpn install script from nord runs faster on these. They're still a overall slower install though.

`bash <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/setup-nord-router.sh)`

## For detailed instructions, consult the appropriate folder.
