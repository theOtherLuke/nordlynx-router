# NordVPN Router - WebUI
>[!WARNING]
>THIS WILL LISTEN ON *ALL* INTERFACES. I AM WORKING ON UPDATING THIS TO LIMIT IT TO A SPECIFIC INTERFACE. FOR NOW, MAKE SURE YOU APPLY APPROPRIATE FIREWALL RULES TO PREVENT UNAUTHORIZED ACCESS.


#### *2025-05-23*
I have developed a basic webui using node.js and websockets. In the coming weeks I hope to post a working version along with installation instructions. I will also be integrating an option to install the webui as part of the `setup-router.sh` script. Long weekend here, so I'll probably be working on this a bit.

### Features -
* Pages for status, settings, account, about, and login
* Uses bash scripts on the backend to interact with the service and serve info to the node server
* Login page allows for logging the router in to your NordVPN account *(work in progress)*
* Settings page allows you to change many of the settings by clicking on the appropriate link for each
* Status page shows current status and updates at regular intervals(5 seconds, configurable in the server.js file)
* Account page shows account info(same as `nordvpn account` but in the webui)
* About page currently only show the nordvpn version

### Future Features -
* Multi-node clustering for managing/monitoring multiple instances
* Ability to change settings requiring additional user input(eg. firewallmark, dns)
* Ability to add/remove whitelist items
* Mobile device friendly page rendering
* and possibly more...

## INSTALLATION

### Install node.js
``` bash
latest_version=$(wget -qO- https://deb.nodesource.com/ | grep -Po 'setup_\K[0-9]+(?=\.x)' | sort -nr | head -1)
bash < <(wget -qO - https://deb.nodesource.com/setup_"$latest_version".x)
apt install nodejs -y
```

### Create directory structure
``` bash
mkdir /root/webui
mkdir /root/webui/node_modules
mkdir /root/webui/public
mkdir /root/webui/scripts
mkdir /root/webui/ssl
mkdir /root/webui/views
```

### Download and save files
``` bash
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/index.js" -O /root/webui/index.js
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/launcher.sh" -O /root/webui/launcher.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/package-lock.json" -O /root/webui/package-lock.json
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/package.json" -O /root/webui/package.json
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/public/style.css" -O /root/webui/public/style.css
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/about.sh" -O /root/webui/scripts/about.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/get-nord.sh" -O /root/webui/scripts/get-nord.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/login.sh" -O /root/webui/login.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/toggle-settings.sh" -O /root/webui/scripts/toggle-settings.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/views/index.ejs" -O /root/webui/views/index.ejs
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/systemd-service/nord-webui.service" -O /etc/systemd/system/nord-webui.service
```

### Make scripts executable
``` bash
chmod +x /root/webui/launcher.sh
chmod +x /root/webui/scripts/*.sh
```

### Install node modules
``` bash
cd /root/webui
npm install ws express
```

### Create the self-signed certificates
``` bash
openssl req -nodes -new -x509 -keyout /root/webui/ssl/key.pem -out /root/webui/ssl/cert.pem
```
- Answer the questions for the certificates. They're all optional, but I usually at least provide country and state/province.
``` bash
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:
Email Address []:
```

### Enable and start the service so it starts on boot
``` bash
systemctl daemon-reload
systemctl enable --now nord-webui.service
```

## ...or use the setup script
``` bash
bash < <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/setup-webui.sh)
```

In my limited testing, this script failed at the downloading files step once. Running the script again resulted in success.
