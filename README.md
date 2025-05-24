# Linux based NordVPN router

### ***While I test and ultimately use these scripts on my own setups, I would not consider them "production-ready", so use them at your own risk. I suggest following the write-up in the debian folder. Replace the network configuration with what works for you. You don't necessarily have to use netplan. Even better, break down the scripts and follow the steps, or even write your own script. As always, I do welcome suggestions and corrections.***

## For those following along, here are some status updates-
I have been doing *a lot* of studying. I'm doing my best to learn and better understand how to script in bash. I have previously worked in c#, c, c++, vb, and basic, but only for very small and non-critical uses like school or simple utilities for personal use, and it's been a *very* long time since my last line of code. I hope my continued education is evident in the structure, perfomance, and logic in these scripts. As always, I welcome input, coaching, correction, and ideas.

*Update 2025-05-23*

I have developed a webui for this project, which I am using on my setups. The files have been uploaded as well as instructions and script for setup. I have also added the option to install it as part of the main setup script. 

---
### I created this to help others build and configure their own whole-network router using NordVPN

The idea is to be able to use the native linux app for NordVPN to create a whole-network vpn router. So far I have been able to get this router working on Ubuntu, Debian, Fedora, CentOS, and AlmaLinux. Every version of the install has the same packages being used for portability between distros. *However*, the other various distros were just a proof-of-concept and I will not be pursuing further development. I will only be continuing development on the debian version. The information for the other distros will be retained for now for those who are interested.

***We use these packages:***

*Network configuration:*  netplan.io

*Firewall configuration:*  iptables-persistent

*dhcp server:*  dnsmasq + dnsmasq-utils

Use the script below for debian, or follow the instructions in the appropriate folder in this repository.

## Recommended system minimums for lxc containers

1 core

4GB drive

128MB RAM

128MB swap (not sure how reducing/removing swap affects this yet)

2 network interfaces (the script requires 2)

## Installation on Debian 12

*See [debian/old-version.md](https://github.com/theOtherLuke/nordlynx-router/blob/main/debian/old-version.md) for original writeup*

**Run the install script**
> [!WARNING]
> The Debian script has only been tested and verified to work on a debian 12 lxc container. It *should* work on any debian derivative, but I cannot guarantee that.
>

- Using wget:

```
bash < <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)
```
- Using curl:

```
bash < <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)
```

## For detailed instructions, consult the appropriate folder.
