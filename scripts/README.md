# Utility Scripts
For each given script, download and make executable.
```
chmod +x <script-name>.sh
```
## nord-settings.sh
Simple utility to easily change NordVPN settings.

## nord-login.sh
Simple utility to assist the NordVPN login process.
Follow the instructions on-screen.

This script in particular needs to be run from a terminal/shell/etc. where you can copy and paste to and from a browser.

## setup-router.sh
This script will setup either a basic router or a NordVPN router in a Debain LXC container. The user will be given a choice between the 2 at runtime. Debian derivatives *may* work, but it is not guaranteed. I have only tested any of this on an LXC container running Debian Bookworm.
- Using wget:
```
bash <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)
```
- Using curl:
```
bash <(curl -sSf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/scripts/setup-router.sh)
```

Follow the on-screen prompts.

Minimum system requirements for LXC. Requirements for a full VM or bare-metal may be, and probably are, different. In proxmox, I typically leave the defaults.
- 1 core
- 128MB RAM
- 128MB swap
- 4GB drive(8GB recommended)
- 2 network interfaces(WAN set to dhcp, LAN set to static)

This does not install and configure the monitor script like the previous install script.

**I have only tested this in an LXC container, not in a VM or bare-metal, so YMMV**

### *More to come...*
