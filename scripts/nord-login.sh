#!/usr/bin/env bash

license(){
    echo -e '\e[1;32m'
    cat <<EOF
MIT License

Copyright (c) 2025 nodaddyno

Permission is hereby granted, free of charge, to any person obtaining a
     copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
                      the following conditions:

The above copyright notice and this permission notice shall be included
        in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
       SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF
    echo -e '\e[0m'
}

clear && license && sleep 1
n_login_url=
while :; do
    read -ra n_redirect_url < <(nordvpn login)
    if [[ ${n_redirect_url[*]} =~ (You are already logged in) ]]; then
        echo -e "\e[1;32mYou are already logged in.\e[0m"
        exit
    fi
    if [[ ${n_redirect_url[-1]} =~ (login-redirect) ]]; then
        n_login_url="${n_redirect_url[-1]}"
        break
    fi
    sleep 2
done

wt_title="NordVPN Login"
wt_prompt="1 - Copy this link and paste it in your browser:
        ${n_login_url}

2 - Cancel any request to open a new window.
3 - Right-click on the 'Continue' button and copy the link.
4 - Paste the link here:"

n_callback_url=$(whiptail --title "${wt_title}" --inputbox "${wt_prompt}" 0 0 3>&1 1>&2 2>&3)

nordvpn login --callback "$n_callback_url"
