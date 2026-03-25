# NordLynx Router Running on Debian 13
2025-12-07

Here I will be documenting my progress on migrating to Debian 13
---
My progress slowed recently due to poor internet coverage. I should be finalizing the Debian 13 version soon.

I  discovered my problem is that Debian 13 seems to not like using iptables for routing. That and it seems setting up ipv4 forwarding is more involved. I believe I have found a solution that uses the default `nftables` instead. This is what I have so far. These details and config options are subject to change as I continue to test. Also, please excuse any of my lysdexic typing.

---
2026-03-24

I discovered another issue with debian 13: sysctl.conf is not loading. The solution was to create a oneshot service to load it at boot.

I cleaned up the nftables rules and tightened them up a bit.

I cleaned up the install script. Still no pretty whiptail dialogs. I added the option to set DNS server(s) in case some have issue with that. Personally, I have OPNsense point at pihole behind the VPN.

I lost internet connectivity behind NordVPN after updating to 4.5.0 on my debian 12 lxc today. So, today I have switched to debian 13 for my production VPN lxc using this script. Unfortunately, there is a bug running the script like the previous one using `bash < <(...)`. You will need to `wget` or `curl` it and run it locally.

I don't have plans to write any type of migration script to go from debian 12 to 13. This lxc is so fast to create using this script, it wouldn't make sense.

```bash
wget https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/setup-13.sh

# or

curl https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/setup-13.sh

# and then

chmod +x setup setup-13.sh
./setup-13.sh
```
### Create the container
	* 1 core
	* min 128MB RAM
	* 8GB Storage
	* 2 NICs - 1 static(LAN), 1 dhcp(WAN)

*You can change the WAN interface to static after setup.*

### Install requisites
```bash
# ensure your container is up to date
apt update
apt upgrade -y

# install dnsmasq
apt install dnsmasq -y

# install nordvpn cli client
sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)
```

### Configure network interfaces
I may still use `netplan` for it's modular nature. For now I'm testing with the default networking.

`/etc/network/interfaces`
``` bash
auto lo
iface lo inet loopback

auto __WAN_IF__ # WAN intreface
iface __WAN_IF__ inet dhcp

auto __LAN_IF__ # LAN interface
iface __LAN_IF__ inet manual
	address __LAN_NET__/24
```
Remember, we don't need to set gateway or nameservers here. They are configured via dhcp on the WAN interface. We will override them on the LAN with `dnsmasq`.

...and reload.
```bash
systemctl restart networking
```

### Enable ipv4 forwarding

`/etc/sysct.conf`
```bash
# /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
```
#### Load the new `/etc/sysctl.conf`
```
sysctl -f /etc/sysctl.conf
```
You should see the newly added configuration options at the bottom.
```bash
$ sysctl -f /etc/sysctl.conf
...
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
```

Unfortunately, Debian 13 doesn't load `/etc/sysctl.conf` correctly in an unprivileged containers. There is a simple fix though: run a one-shot service on boot.

```bash
nano /etc/systemd/system/load-sysctl.service
```
Add the contents:
```ini
[Unit]
Description=Load sysctl settings from /etc/sysctl.conf
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -f /etc/sysctl.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```
enable the service
```bash
systemctl daemon-reload
systemctl enable load-sysctl.service
```
and run it to ensure it works
```bash
systemctl start load-sysctl.service
```


### Configure `nftables`
Change the LAN interface name for yours. WAN interface should be configured as `nordlynx`.

`/etc/nftables.conf`
```
#!/usr/sbin/nft -f

# VARIABLES
define LAN_IF = __LAN_IF__
#define WAN_IF = __WAN_IF__
define WAN_IF = nordlynx

flush ruleset

# MANGLE (connmark)
table ip mangle {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;

        iifname $LAN_IF ct mark set 0xe1f1 comment "nord-router"
    }
}

# FILTER (forwarding)
table ip filter {
    chain input {
        type filter hook input priority filter; policy drop;

        # Allow loopback
        iifname "lo" accept

        # Allow established/related
        ct state established,related accept

        # Allow SSH on eth1 only
        iifname $LAN_IF tcp dport 22 accept

        # DHCP (server on eth1)
        iifname $LAN_IF udp sport 68 udp dport 67 accept
        iifname $LAN_IF udp sport 67 udp dport 68 accept
    }

    chain forward {
        type filter hook forward priority filter; policy drop;

        # Allow established/related return traffic
#        iifname $LAN_IF oifname WAN_IF ct state established,related accept
        iifname $WAN_IF oifname $LAN_IF ct state established,related accept

        # Allow outbound forwarding from eth1 → nordlynx
        iifname $LAN_IF oifname $WAN_IF accept
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}

# NAT (masquerade)
table ip nat {
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;

        oifname $WAN_IF masquerade
    }
}
```
...and reload.
```bash
systemctl restart nftables

# or

nft -f /etc/nftables.conf

# or alternatively...
# make it executable and run it
chmod +x /etc/nftables.conf
/etc/nftables.conf
```

### Configure dhcp server

`/etc/dnsmasq.conf`
``` bash
# lan facing interface
interface=__LAN_IF__

# tell dnsmasq to not serve dhcp on this interface
no-dhcp-interface=__WAN_IF__

# dhcp range <strarting_ip>,<ending_ip>,[netmask,]<lease_time>
# netmask is optional
dhcp-range=__DHCP_START__,__DHCP_END__,__DHCP_LEASE__

# override WAN dns servers for LAN. useful for pointing at pihole.
# this may also be set to a local dns server on you wan port.
#    eg-
#      wan net = 172.16.20.0/24
#      lan net = 192.168.200.0/24
#      local dns server = 172.16.20.55
# Comma-separated list of dns servers
# dhcp_option=6,172.16.20.55
dhcp-option=6,__NAMESERVERS__

# gateway - this will be the static ip of the lan interface by default.
# Only change this if you require something else.
#dhcp-option=3,__GATEWAY__

# dhcp cache size
cache-size=1000
```
## My latest hardware iteration
I have moved my router to a Minisforum MS-01 12900H. I would have preferred the MS-A2 9955HX for its homogeneous cores, but I couldn't justify the price for way more power than I will ever need for this host. Plus, Plex likes the intel quick-assist. With OPNsense fully provisioned, I still have way more than enough headroom to virtualize a ddns updater, pihole, nord router, docker, and even a plex server with room to spare.

I pass the i226-V(not the i226-LM) directly to OPNsense as the WAN. Then, I create 3 virtual bridges in Proxmox: LAN(vmbr0 - connected to a 10gb SFP port), DMZ(vmbr1), VPN(vmbr2). My pihole lives in the DMZ. The Nord router lives between DMZ(WAN-side) and VPN(LAN-side). Firewall filter and nat rules direct internet traffic from LAN through the VPN interface. LAN can access DMZ, but not the other way around. VPN is configured as a gateway. I also configure all interface addresses in OPNsense as static, except WAN, to prevent slow booting if nord isn't quite up yet. So far this seems to work pretty well. One could easily implement vlans with this setup as well.
