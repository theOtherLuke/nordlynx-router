#!/usr/bin/env bash

# MIT License

# Copyright (c) 2025 nodaddyno

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
cleanup() {
    pkill -P $$
    echo -e "\e[0m"
}

trap cleanup EXIT

# install latest nodejs
working-dots() {
    while :; do
        echo -n "."
        sleep .5
    done
}
echo -ne "\e[1;32mInstalling NodeJS..."
working-dots &
latest_version=$(wget -qO- https://deb.nodesource.com/ | grep -Po 'setup_\K[0-9]+(?=\.x)' | sort -nr | head -1) &> /dev/null
bash < <(wget -qO - https://deb.nodesource.com/setup_"$latest_version".x) &> /dev/null
apt install nodejs -y &> /dev/null
echo -e "\e[0m"

# create directory structure
echo -ne "\e[1;32mCreating directory structure..."
mkdir /root/webui &> /dev/null
mkdir /root/webui/node_modules &> /dev/null
mkdir /root/webui/public &> /dev/null
mkdir /root/webui/scripts &> /dev/null
mkdir /root/webui/ssl &> /dev/null
mkdir /root/webui/views &> /dev/null
echo -e ".\e[0m"

# download files
echo -ne "\e[1;32mDownloading files."
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/index.js" -qO /root/webui/index.js
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/launcher.sh" -qO /root/webui/launcher.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/package-lock.json" -qO /root/webui/package-lock.json
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/package.json" -qO /root/webui/package.json
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/public/style.css" -qO /root/webui/public/style.css
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/about.sh" -qO /root/webui/scripts/about.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/get-nord.sh" -qO /root/webui/scripts/get-nord.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/login.sh" -qO /root/webui/login.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/scripts/toggle-settings.sh" -qO /root/webui/scripts/toggle-settings.sh
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/node-server/views/index.ejs" -qO /root/webui/views/index.ejs
wget "https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/systemd-service/nord-webui.service" -qO /etc/systemd/system/nord-webui.service
echo -e ".\e[0m"

# make scripts executable
echo -ne "\e[1;32mMaking scripts executable..."
chmod +x /root/webui/launcher.sh &> /dev/null
chmod +x /root/webui/scripts/*.sh &> /dev/null
echo -e "\e[0m"

# install node modules
echo -ne "\e[1;32mInstalling node modules..."
cd /root/webui &> /dev/null
npm install ws express &> /dev/null
echo -e ".\e[0m"

# create self-signed certs
echo -ne "\e[1;32mCreating self-signed certificates..."
openssl req -nodes -new -x509 -keyout /root/webui/ssl/key.pem -out /root/webui/ssl/cert.pem &> /dev/null
echo -e ".\e[0m"

# enable and start the service
echo -ne "\e[1;32mEnabling and starting node-webui.service..."
systemctl daemon-reload &> /dev/null
systemctl enable --now nord-webui.service &> /dev/null
echo -e ".\e[0m"

# byeee
jobs -p | xargs -I{} kill {}
echo -e "\e[1;32mDONE!\e[0m"
exit 0
