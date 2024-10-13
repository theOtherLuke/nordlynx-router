# Linux based NordVPN router

## ***Many apologies for any chaos or confusion. Sometimes I get excited and share before ready. These install scripts are not yet polished and 100% reliable yet. Use at your own risk. I suggest following the write-up in the debian folder. Replace the network configuration with what works for you. Or break down the script and follow the steps or even write your own.***

## For those following along, here are some status updates-
I have been doing *a lot* of studying. I'm doing my best to learn and better understand how to script in bash. I have previously worked in c#, c, c++, vb, and basic, but only for very small and non-critical uses like school or simple utilities for personal use, and its been a *very* long time since my last line of code. I hope my continued education is evident in the structure, perfomance, and logic in these scripts. As always, I welcome input, coaching, correction, and ideas.

As of 2024-10-13:

  1- A new version of the monitor script has been written. I am currently testing it. This new version is much lighter, simpler, and more effective.
  
  2- An actually functioning version of an install script is also in the works. The new version is almost a complete re-write. I'm working to make the process flow in a logical and efficient manner.
  
  3- Updated vesions of the config files have already been uploaded. Instead of lots of processing to filter and add/remove lines from a single universal config.yaml, I have opted for 3 separate versions to fit the 3 possibilities I have had success with in my setups. We would use one for each interface and each would simply be updated with 1 or 2 sed commands and be done. I may add a config-ap.yaml if I ever want to try making this a wifi access point as well. That would only be for specific use cases though, so would not likely be any time soon. I am a bit of a completist though, so I may do it just for completeness. We'll see.

***Updated check-connection.sh has been uploaded*** There is no need to change the service file. Simply replace the old script with the new one and restart the service.

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

Be forewarned, CentOS and AlmaLinux are a significantly slower install process due to needing to add repos and the oddly slow speed of dnf operations on these distros. Interestingly, the nordvpn install script from nord runs faster on these. They're still an overall slower install though.

`bash <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/setup-nord-router.sh)`

## For detailed instructions, consult the appropriate folder.
