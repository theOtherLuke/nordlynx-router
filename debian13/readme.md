# NordLynx Router Running on Debian 13
2025-12-07

Here I will be documenting my progress on migrating to Debian 13
---

I  discovered my problem is that Debian 13 seems to not like using iptables for routing. That and it seems setting up ipv4 forwarding is more involved. I believe I have found a solution that uses the default `nftables` instead. This is what I have so far. These details and config options are subject to change as I continue to test. Also, please excuse any of my lysdexic typing.

### Install requisites
```bash
# ensure your host is up to date
apt update
apt upgrade -y

# install dnsmasq
apt install dnsmasq dnsmasq-utils -y

# install nordvpn cli client
sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh)
```

#### Configure network interfaces
I may still use `netplan` for it's modular nature. For now I'm testing with the default networking.

`/etc/network/interfaces`
``` bash
auto lo
iface lo inet loopback

auto eth0 # WAN intreface
iface eth0 inet dhcp

auto eth1 # LAN interface
iface eth1 inet static
	address 192.168.200.1/24
```
Remember, we don't need to set gateway or nameservers here. They are configured via dhcp on the WAN interface. We will override them on the LAN with `dnsmasq`.

...and reload.
```bash
systemctl restart networking
```

#### Enable ipv4 forwarding
Many sources suggest putting this in `/etc/sysctl.d/99-ipforward` instead.

`/etc/sysct.conf`
```bash
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
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
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
```
As you can see, it loads `/etc/sysctl.conf` last anyways, so either way should work.

#### Configure `nftables`
Change the LAN interface name for yours. WAN interface is not required to be configured for this. In fact, leaving it unconfigured creates a natural killswitch for LAN traffic if Nord goes down. I'm sure you could optionally configure it to allow traffic forwarding to WAN if Nord is down.

`/etc/nftables.conf`
```pgsql
#!/usr/sbin/nft -f

# =============================
# Basic Nord router configuration
# Debian 13 / nftables
# =============================

# ---- EDIT THESE INTERFACE NAMES ----
define NORD_IF = "nordlynx"     # Upstream / nordvpn interface
define WAN_IF = "eth0"     # Upstream / unfiltered internet interface. not used for our basic nord router
define LAN_IF = "eth1"     # Internal / client interface
define LAN_NET = 192.168.200.0/24 # Internal network we configured in /etc/network/interfaces and /etc/dnsmasq.conf
# ------------------------------------


# Flush existing ruleset on load
flush ruleset

# ============================
# NAT TABLE
# ============================
table ip nat {

    chain prerouting {
        type nat hook prerouting priority -100; policy accept
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # NAT for outbound traffic
        oifname $NORD_IF ip saddr $LAN_NET masquerade
    }
}

# ============================
# FILTER TABLE
# ============================
table ip filter {

    # Default drop for safety
    chain input {
        type filter hook input priority 0; policy drop;

        # allow local loopback
        iif "lo" accept

        # allow established/related
        ct state established,related accept

        # allow LAN to talk to router
        iifname $LAN_IF accept

        # allow ping from outside
        # iifname $NORD_IF icmp type echo-request accept

        ct state invalid drop
    }

    # Forwarding logic (router path)
    chain forward {
        type filter hook forward priority 0; policy drop;

    	ct state established,related accept

        # allow LAN to NORD
        iifname $LAN_IF oifname $NORD_IF accept

        # allow return traffic NORD to LAN
        iifname $NORD_IF oifname $LAN_IF ct state related,established accept

    	ct state invalid drop
    }

    # allow outbound traffic from the router itself
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```
...and reload.
```bash
systemctl restart nftables
```

#### Configure dhcp server

`/etc/dnsmasq.conf`
``` bash
# lan facing interface
interface=eth1

# tell dnsmasq to not serve dhcp on this interface
#no-dhcp-interface=

# dhcp range <strarting_ip>,<ending_ip>,[netmask,]<lease_time>
# netmask is optional
dhcp-range=192.168.200.50,192.168.200.150,255.255.255.0,12h

# override WAN dns servers for LAN. useful for pointing at pihole.
# this may also be set to a local dns server on you wan port.
#    eg-
#      wan net = 172.16.20.0/24
#      lan net = 192.168.200.0/24
#      local dns server = 172.16.20.55
# dhcp_option=6,172.16.20.55 #<-- this works without additional configuration
dhcp-option=6,1.1.1.1,8.8.8.8

# gateway - this is the static ip of the lan interface
dhcp-option=option:router,192.168.200.1

# dhcp cache size
cache-size=1000
```
## My latest iteration
I have moved my router to a Minisforum MS-01 12900H. I would have preferred the MS-A2 9955HX for its homogeneous cores, but I couldn't justify the price for way more power than I will ever need for this router. Plus, Plex likes the intel quick-assist. With OPNsense fully provisioned, I still have way more than enough headroom to virtualize a ddns updater, pihole, nord router, docker, and even a plex server with room to spare.

I pass the i226-V(not the i226-LM) directly to OPNsense as the WAN. Then, I create 3 virtual bridges in Proxmox: LAN(vmbr0 - connected to a 10gb SFP port), DMZ(vmbr1), VPN(vmbr2). My pihole lives in the DMZ. The Nord router lives between DMZ(WAN-side) and VPN(LAN-side). Firewall filter and nat rules direct internet traffic from LAN through the VPN interface. LAN can access DMZ, but not the other way around. VPN is configured as a gateway. I also configure all interface addresses in OPNsense as static outside their respective dhcp ranges, except WAN, to prevent slow booting if nord isn't quite up yet. So far this seems to work pretty well. One could easily implement vlans with this setup as well.
