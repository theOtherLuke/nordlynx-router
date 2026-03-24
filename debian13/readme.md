# NordLynx Router Running on Debian 13
2025-12-07

Here I will be documenting my progress on migrating to Debian 13
---
My progress slowed recently due to poor internet coverage. I should be finalizing the Debian 13 version soon.

I  discovered my problem is that Debian 13 seems to not like using iptables for routing. That and it seems setting up ipv4 forwarding is more involved. I believe I have found a solution that uses the default `nftables` instead. This is what I have so far. These details and config options are subject to change as I continue to test. Also, please excuse any of my lysdexic typing.

### Install requisites
```bash
# ensure your host is up to date
apt update
apt upgrade -y

# install dnsmasq, nftables
apt install dnsmasq nftables -y

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
Many sources suggest putting this in `/etc/sysctl.d/99-ipforward` instead.

`/etc/sysct.conf`
```bash
# /etc/sysctl.d/99-router.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
```
#### Load the new `/etc/sysctl.conf`
```
sysctl --system
```
You should see the newly added configuration options at the bottom.
```bash
$ sysctl --system
* Applying /usr/lib/sysctl.d/10-coredump-debian.conf ...
* Applying /usr/lib/sysctl.d/50-default.conf ...
* Applying /usr/lib/sysctl.d/50-pid-max.conf ...
* Applying /etc/sysctl.d/99-ipforward.conf ...
* Applying /etc/sysctl.d/99-rpfilter.conf ...
* Applying /etc/sysctl.conf ...
...
...
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
```
As you can see, it loads `/etc/sysctl.conf` last anyways, so either way should work.

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
Change the LAN interface name for yours. WAN interface is not required to be configured for this. In fact, leaving it unconfigured creates a natural killswitch for LAN traffic if Nord goes down. I'm sure you could optionally configure it to allow traffic forwarding to WAN if Nord is down.

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
# dhcp_option=6,172.16.20.55 #<-- this works without additional configuration
dhcp-option=6,__NAMESERVERS__

# gateway - this is the static ip of the lan interface
dhcp-option=3,__GATEWAY__

# dhcp cache size
cache-size=1000
```
## My latest iteration
I have moved my router to a Minisforum MS-01 12900H. I would have preferred the MS-A2 9955HX for its homogeneous cores, but I couldn't justify the price for way more power than I will ever need for this router. Plus, Plex likes the intel quick-assist. With OPNsense fully provisioned, I still have way more than enough headroom to virtualize a ddns updater, pihole, nord router, docker, and even a plex server with room to spare.

I pass the i226-V(not the i226-LM) directly to OPNsense as the WAN. Then, I create 3 virtual bridges in Proxmox: LAN(vmbr0 - connected to a 10gb SFP port), DMZ(vmbr1), VPN(vmbr2). My pihole lives in the DMZ. The Nord router lives between DMZ(WAN-side) and VPN(LAN-side). Firewall filter and nat rules direct internet traffic from LAN through the VPN interface. LAN can access DMZ, but not the other way around. VPN is configured as a gateway. I also configure all interface addresses in OPNsense as static outside their respective dhcp ranges, except WAN, to prevent slow booting if nord isn't quite up yet. So far this seems to work pretty well. One could easily implement vlans with this setup as well.
