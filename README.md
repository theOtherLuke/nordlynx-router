# Linux based NordVPN router

## ***Many apologies for any chaos or confusion. Sometimes I get excited and share before ready. These install scripts are not yet polished and 100% reliable yet. Use at your own risk. I suggest following the write-up in the debian folder. Replace the network configuration with what works for you. Or break down the script and follow the steps or even write your own.***

## For those following along, here are some status updates-
I have been doing *a lot* of studying. I'm doing my best to learn and better understand how to script in bash. I have previously worked in c#, c, c++, vb, and basic, but only for very small and non-critical uses like school or simple utilities for personal use, and its been a *very* long time since my last line of code. I hope my continued education is evident in the structure, perfomance, and logic in these scripts. As always, I welcome input, coaching, correction, and ideas.

*As of 2025-02-20:*

The install script has been rewritten and only *officially* supports debian 12 in an lxc container, but *should* work on debian derivatives, VMs and bare-metal. See the link below.

Some other new scripts have been uploaded as well:
- **connect-nord.sh** (together with connect-nord.conf) is a cli script for connecting and maitaining the connection. Should be able to use it with the monitor service in place of check-connection.sh.
- **nord-settings.sh** makes applying your nord settings easier.
- **nord-login.sh** makes logging in to NordVPN easier. You still need copy-paste functionality for this.

### I created this to help others build and configure their own whole-network router using NordVPN

The idea is to be able to use the native linux app for NordVPN to create a whole-network vpn router. So far I have been able to get this router working on Ubuntu, Debian, Fedora, CentOS, and AlmaLinux. Every version of the install has the same packages being used for portability between distros.

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

2 network interfaces(the scripts require 2)

Ubuntu and Fedora require dns server address to be manually configured. I set it in the container settings in Proxmox

## Debian, Ubuntu, Fedora, CentOS, AlmaLinux
I have not compared the on-disk or backup sizes of each of these.

*See [debian/old-version.md](https://github.com/theOtherLuke/nordlynx-router/blob/main/debian/old-version.md) for original writeup*

**Run the install script**
> [!WARNING]
> The Debian script has only been tested and verified to work on a debian 12 lxc container. It *should* work on any debian derivative, but I cannot guarantee that.
>
> The Fedora/CentOS/AlmaLinux, aka RPM version is ***not*** production ready. Use it only for reference.

*Debian*
- Using wget:

`bash <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)`
- Using curl:

`bash <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)`

*Fedora,CentOS,AlmaLinux*
- Using curl

I only got the RPM version working for my own proof of concept. As I don't use any RPM distros, I don't plan to maintain support, but it will remain in the repo for those interested.

`bash <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/setup-nord-router.sh)`

## For detailed instructions, consult the appropriate folder.
