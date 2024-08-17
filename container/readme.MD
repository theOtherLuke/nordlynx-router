
# Pre-configured LXC container for use in Proxmox

## Acquire Template

**Step 1: Download the template from one of the links below**

https://drive.google.com/file/d/1-1Lp3PjpO49Yb26iDbzvvmC4Wj9mAKtb/view?usp=sharing

https://file.io/cz6iNgsNWEXm

**Step 2: Upload the image to your Proxmox host as a container template

**Step 3: Create a new container using the image and configure**

Click 'Create CT'

Configure as following

**General** - name the container and create a password

**Template** - Select the nordvpn container

**Disks** - set Disk size to at least 2GB, ideally 4GB

**CPU** - leave as is

**Memory** - set Memory and Swap to at least 128MB

**Network** - set Bridge to your WAN vmbr, set ipv4 to DHCP

**DNS** - leave as is

**Confirm** - Click Finish

Before starting the container, add the second network interface for LAN.

Select the container.

Go to the Network section.

Click Add

Name = eth1

Bridge = LAN facing vmbr

IPv4 = Static

Leave all other fields blank

**Step 4: Configure LAN settings**

Edit /etc/dnsmasq.conf and /etc/network/interfaces to your own network settings if you don't want to use the defaults

**Step 5: Login**

Start the container and login as root. You will be greeted with instructions for logging in to NordVPN.

**Step 6: Finish**

Set nordvpn options such as autoconnect. Connect nordvpn 'nordvpn connect'. 
