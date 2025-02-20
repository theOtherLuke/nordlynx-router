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
This script will setup either a basic router or a NordVPN router in a debain LXC container. The user will be given a choice between the 2 at runtime. Debian derivatives *may* work, but it is not guaranteed. I have only tested any of this on x86/x64 running Debian Bookworm.

Follow the on-screen prompts.

Minimum system requirements. Requirements for a full VM or bare-metal may be, and probably are, different. In proxmox, I typically leave the defaults.
- 1 core
- 128MB RAM
- 128MB swap
- 4GB drive(8GB recommended)
- 2 network interfaces(WAN set to dhcp, LAN set to static)

**I have not tested this on a VM or bare-metal so YMMV**

#### *More to come...*
