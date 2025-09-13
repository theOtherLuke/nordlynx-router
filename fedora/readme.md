# And to top it all off...like a nice hat, FEDORA!
## I don't personally use Fedora, but I know some people do.
### I'm not sure why. In my experience this week with getting this project working on Fedora, I have found it to be much bulkier and noticeably slower. However, in the interest of maximizing the compatibility of my project, here it is.

### Start with a new container:

*General* - enter a name and set your password

*Template* - select the latest Fedora template. Download one if you haven't already

*Disks* - allocate at least 4GB for Drive size

*CPU* - leave as is, minimum 1 core

*Memory* - At least 128MB on Memory and Swap. I leave these as is

*Network* - select the bridge for your WAN facing interface. Under IPv4 select DHCP. We will add the LAN interface later

*DNS* - Like the Ubuntu version, enter your DNS server here.

*Confirm* - Click Finish to create the container

### Add your LAN interface

Select your container, go to Network, Click *Add*

Enter a name for the interface, usually in the same vein as the WAN interface. Example- WAN=eth0, LAN=eth1

Select the bridge to connect this interface to. This should be different than the WAN bridge

Under IPv4 select *Static*, but don't enter any details here. This will be done inside the container.

Click *Add*

### Start the container

Once the container is started, login as **root** and update using `dnf upgrade`

**Install required packages** `dnf install iptables-services dnsmasq dnsmasq-utils netplan.io nano -y`

**Configure dnsmasq** `nano /etc/dnsmasq.conf`. Make sure you change it to match your setup or needs.

```ini
# Your LAN interface
interface=eth1

# Your dhcp pool and lease time
dhcp-range=10.0.9.50,10.0.9.88,12h
```

Enable dnsmasq

`systemctl enable dnsmasq`

**Configure your network interfaces**

Disable conflicting NetworkManager `systemctl disable NetworkManager`

Disable conflicting systemd-resolved `systemctl disable systemd-resolved`

`nano /etc/netplan/config.yaml`

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses:
      - 10.0.9.1/24
```

That is all the info you need in the netplan config file.

Apply the changes `netplan try`. If you are satisfied with the changes you can make them permanent by pressing ENTER before the timer times out.

**Enable forwarding**

This will overwrite the file. It would be good idea to make a backup  `cp /etc/sysctl.conf /etc/sysctl.conf.bak`

`echo net.ipv4.ip_forward=1 > /etc/sysctl.conf`


**Configure your firewall(iptables)**

There's one extra step to perform in Fedora. You have to make sure firewalld is not enabled and you have to enable the iptables service.
```bash
systemctl disable --now systemd-firewalld
systemctl enable --now iptables
```

Create the rules. The easiest way is to open the file and paste them in. `nano /etc/sysconfig/iptables` ip6tables would be for IPv6, obviously.

```bash
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i eth1 -m comment --comment nord-router -j CONNMARK --set-xmark 0xe1f1/0xffffffff
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

You can test the forwarding by changing *nordlynx* to *<WAN_interface>* in `/etc/sysconfig/iptables` temporarily and reboot. Connect a client and make sure it can connect through to the internet. If it works then congratulations! You just created a basic router.

Make sure you change the rules file back to nordlynx.

**Install NordVPN**

This is the same on every distro I have tested. Follow the instructions on the nordvpn website to install and configure.

Install the NordVPN app
```bash
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
```

Login
```bash
nordvpn login
```
Copy the link and paste in your browser. Sign in. Cancel the request to open a new window. Right-click the *CONTINUE* button and copy the link. Paste the new link into the login command. Don't forget the double quotes.
```bash
nordvpn login --callback "<link>"
```

If all went well, you should be logged in and ready to connect.

**Configure NordVPN Settings**

Check the current settings `nordvpn settings`

Change settings using `nordvpn set <setting> [on|off]`

Routing ***must*** be enabled to pass traffic from LAN `nordvpn set routing on`

It appears that lan-discovery *may* need to be enabled as well `nordvpn set lan-discovery on`

This is also where you configure auto connect `nordvpn set auto-connect on`, which isn't needed if using the monitor service.

Personally, I disable analytics `nordvpn set analytics off`. After all, I didn't get a VPN for privacy just to let the provider collect data.

**Connect NordVPN**

`nordvpn c` or `nordvpn connect`

# DONE
