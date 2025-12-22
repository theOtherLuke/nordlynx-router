#!/usr/bin/env bash

### COLORS
c_gry='\e[1;30m'
c_red='\e[1;31m'
c_grn='\e[1;32m'
c_yel='\e[1;33m'
c_blu='\e[1;34m'
c_mag='\e[1;35m'
c_cyn='\e[1;36m'
c_wht='\e[1;37m'
c_rst='\e[0m'

### VARIABLES
url_sysctl="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/config-files/99-router.conf"
url_nftables="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/config-files/nftables.conf"
url_dnsmasq="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/config-files/dnsmasq.conf"
url_net_cfg="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/debian13/config-files/interfaces"
url_nord_installer="https://downloads.nordcdn.com/apps/linux/install.sh"
url_monitor_service="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/install-monitor-service.sh"
url_webui="https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/setup-webui.sh"
apt_packages=(dnsmasq nftables)

### PRINTF FORMATS
fmt_menu_header="${c_mag}===== %s =====${c_rst}\n"
fmt_menu_item="\r\e[10C${c_cyn} %s) ${c_blu}%s${c_rst}\n"
fmt_query="\e[s${c_cyn} %s ${c_rst}"
fmt_info="\r\e[10C${c_wht}%s${c_rst}\n"
fmt_working="\e[10C${c_grn} %s${c_rst}\e[s"
fmt_warn="${c_yel}  %s${c_rst}\n"
fmt_error="${c_red}  %s${c_rst}\n"
fmt_stat_icon="\e[u\r [ %-3s ] \e[u"
menu_col_width=25

### USER PROVIDED
declare -a net_interfaces
declare -a net_interface_prompt
declare -A net_interface_pool
lan_if=
wan_if=
lan_ip=
subnet=
dhcp_start=
dhcp_end=
dhcp_lease=
nord_country=
nord_group=
nord_options=
not_nord=false

### NORD SETTINGS
declare -A nord_settings_connector
declare -A nord_settings_template=(
    ["Firewall"]="firewall"
    ["Routing"]="routing"
    ["User Consent"]="analytics"
    ["Kill Switch"]="killswitch"
    ["Threat Protection Lite"]="tpl"
    ["Notify"]="notify"
    ["Tray"]="tray"
    ["Auto-connect"]="autoconnect"
    ["IPv6"]="ipv6"
    ["Meshnet"]="meshnet"
    ["DNS"]="dns"
    ["LAN Discovery"]="lan-discovery"
    ["Virtual Location"]="virtual-location"
    ["Post-quantum VPN"]="pq"
    ["ARP Ignore"]="arp-ignore"
)
declare -A nord_settings_actor=(
    ["firewall"]="on"
    ["routing"]="on"
    ["analytics"]="off"
    ["killswitch"]="off"
    ["tpl"]="off"
    ["notify"]="off"
    ["tray"]="off"
    ["autoconnect"]="off"
    ["ipv6"]="off"
    ["meshnet"]="off"
    ["dns"]="off"
    ["lan-discovery"]="on"
    ["virtual-location"]="on"
    ["pq"]="on"
    ["arp-ignore"]="on"
)

### FUNCTIONS
cleanup() {
    pkill -P $$
    printf '\e[0m\e[?25h'
    set +x
}

trap cleanup EXIT

working-dots() {
    printf '\e[s'
    while :; do
        printf "."
        sleep 0.2
    done
}

update-dots() {
    local mode="$1"
    case "$mode" in
        finish)
            printf "\e[u\e[J${c_grn}%s${c_rst}\n" " ✔ DONE"
            kill "$dots_pid" &> /dev/null
            return;;
        gonext)
            printf '\e[s'
            return;;
    esac
}

menuitem() {
    option_color='\e[1;36m'
    item_color='\e[1;34m'
    option=$1
    item=$2
    flag="${3:-}"
    [[ $3 == "__NO__" ]] && nl="" || nl="\n"
    printf "${option_color} %3s) ${item_color}%-*s${nl}" "${option}" $menu_col_width "${item}"
}

menuitem-status() {
    option_color='\e[1;36m'
    item_color='\e[1;34m'
    option=$1
    status="${2:0:12}"
    item=$3
    printf "${option_color} %3s) %-12s ${item_color}%s\n" "${option}" "${status}" "${item}" # status is 6 spaces in
}

query() {
    message="$@"
    printf "\e[s${c_cyn} %s${c_blu}" "$message" >&2
    read -r answer
    printf "%s" "$answer"
    printf "\n" >&2
}

query-reset() {
    printf "\e[u\e[J"
}

validate-ip() {
    IFS="." read -ra o <<< "$1"
    [[ ${#o[@]} -eq 4 ]] &&
    (( o[0] >= 0 && o[0] <= 255 &&
       o[1] >= 0 && o[1] <= 255 &&
       o[2] >= 0 && o[2] <= 255 &&
       o[3] >= 0 && o[3] <= 255 )) || return 1

    (( o[0] == 10 )) && return 0 # 10.0.0.0/8
    (( o[0] == 172 && o[1] >= 16 && o[1] <= 31 )) && return 0 # 172.16.0.0/12
    (( o[0] == 192 && o[1] == 168 )) && return 0 # 192.168.0.0/16
    return 1
}

get-subnet() {
    local ip="$1"
    echo "${ip%.*}"
}

get-octet() {
    local ip="$1"
    local index="${2:-4}"
    (( index < 1 || index > 4 )) && index=4
    IFS=. read -ra octets <<< "$ip"
    echo "${octets[((index-1))]}"
}

query-router-mode() {
    clear
    printf "\n\n$fmt_menu_header\n" "Select Router Mode" >&2
    menuitem "1" "NordVPN Router"
    menuitem "2" "Basic Router"
    menuitem "q" "Quit"
    while response=$(query "Select router mode : "); do
        if [[ $response =~ [qQ1-2] ]]; then
            case ${response,,} in
                1) not_nord=false
                    return;;
                2) not_nord=true
                    return;;
                q) exit 0;;
            esac
        fi
        query-reset
    done
}

get-files() {
    printf "$fmt_working" "Downloading configuration files"
    working-dots & dots_pid=$!
    wget "$url_sysctl" -qO /etc/sysctl.d/99-router.conf || { printf "$fmt_error" "Error downloading $url_sysctl"; exit 7; }
    wget "$url_nftables" -qO /etc/nftables.conf || { printf "$fmt_error" "Error downloading $url_nftables"; exit 7; }
    wget "$url_dnsmasq" -qO /etc/dnsmasq.conf || { printf "$fmt_error" "Error downloading $url_dnsmasq"; exit 7; }
    wget "$url_net_cfg" -qO /etc/network/interfaces || { printf "$fmt_error" "Error downloading $url_net_cfg"; exit 7; }
    update-dots finish
}

write-files() {
    printf "$fmt_working" "Writing configuration files"
    working-dots & dots_pid=$!
    sed -i "s/__LAN_IF__/$lan_if/g" /etc/network/interfaces
    sed -i "s/__LAN_IP__/$lan_ip/g" /etc/network/interfaces
    sed -i "s/__WAN_IF__/$wan_if/g" /etc/network/interfaces
    sed -i "s/__LAN_IF__/$lan_if/g" /etc/nftables.conf
    sed -i "s|__LAN_NET__|$(get-subnet "$lan_ip").0|g" /etc/nftables.conf
    sed -i "s/__WAN_IF__/$wan_if/g" /etc/nftables.conf
    sed -i "s/__LAN_IF__/$lan_if/g" /etc/dnsmasq.conf
    sed -i "s/__DHCP_NETMASK__/255.255.255.0/g" /etc/dnsmasq.conf
    sed -i "s/__DHCP_START__/$dhcp_start/g" /etc/dnsmasq.conf
    sed -i "s/__DHCP_END__/$dhcp_end/g" /etc/dnsmasq.conf
    sed -i "s/__DHCP_LEASE__/$dhcp_lease/g" /etc/dnsmasq.conf
    sed -i "s/__GATEWAY__/$lan_ip/g" /etc/dnsmasq.conf
    sed -i "s/__DNS_SERVERS__/$lan_ip/g" /etc/dnsmasq.conf
    update-dots finish
}

query-wan-interface() {
    clear
    printf "\n\n$fmt_menu_header\n" "Select WAN Interface" >&2
    for (( i=0; i<${#net_interfaces[@]}; i++ )); do
        menuitem "$i" "${net_interfaces[$i]}"
    done
    [[ -n $lan_if ]] && printf "\n$fmt_working %s\n\n" "LAN Interface : " "${lan_if}" >&2
    [[ -n $wan_if ]] && printf "\n$fmt_working %s\n\n" "WAN Interface : " "${wan_if}" >&2
    while response=$(query "Select WAN interface : "); do
        if [[ $response =~ ^[0-9]+$ && $response -lt ${#net_interfaces[@]} && $response -ge 0 ]]; then
            net_interface_pool["${net_interfaces[$response]}"]="WAN"
            wan_if="${net_interfaces[$response]}"
            return
        fi
        query-reset
    done
}

query-lan-interface() {
    clear
    printf "$fmt_menu_header\n" "Select LAN Interface" >&2
    for (( i=0; i<${#net_interfaces[@]}; i++ )); do
        menuitem "$i" "${net_interfaces[$i]}"
    done
    [[ -n $lan_if ]] && printf "\n$fmt_working %s\n\n" "LAN Interface : " "${lan_if}" >&2
    [[ -n $wan_if ]] && printf "\n$fmt_working %s\n\n" "WAN Interface : " "${wan_if}" >&2
    while response=$(query "Select LAN interface : "); do
        if [[ $response =~ ^[0-9]+$ && $response -lt ${#net_interfaces[@]} && $response -ge 0 ]]; then
            net_interface_pool["${net_interfaces[$response]}"]="LAN"
            lan_if="${net_interfaces[$response]}"
            return
        fi
        query-reset
    done
}

query-lan-address() {
    local err=false
    while lan_ip=$(query "Enter an ipv4 address for the LAN interface (no cidr) : "); do
        if validate-ip "$lan_ip"; then
            printf '\e[J'
            break
        fi
        [[ $err == true ]] || { printf "\e[u\e[K$fmt_warn" "Please enter a valid private ipv4 address (no cidr)" >&2; err=true; printf '\e[s'; }
        query-reset
    done
}

query-dhcp-start() {
    local err=false
    printf '\n'
    local subnet=$(get-subnet "$lan_ip")
    while dhcp_start=$(query "Enter a starting dhcp address : ${subnet}."); do
        if (( dhcp_start >= 2 && dhcp_start <= 254 )); then
            dhcp_start="${subnet}.${dhcp_start}"
            if validate-ip "$dhcp_start"; then
                printf '\e[J'
                break
            fi
        fi
        [[ $err == true ]] || { printf "\e[u\e[K$fmt_warn" "Please enter a valid address between ${subnet}.2 and ${subnet}.254" >&2; err=true; printf '\e[s'; }
        query-reset
    done
}

query-dhcp-end() {
    local err=false
    printf '\n'
    local subnet=$(get-subnet $lan_ip)
    local start_octet=$(get-octet "$dhcp_start")
    while dhcp_end=$(query "Enter a ending dhcp address : ${subnet}."); do
        if (( dhcp_end > start_octet && dhcp_end < 254 )); then
            dhcp_end="${subnet}.${dhcp_end}"
            if validate-ip "$dhcp_end"; then
                printf '\e[J'
                break
            fi
        fi
        [[ $err == true ]] || { printf "\e[u\e[K$fmt_warn" "Please enter a valid address between ${dhcp_start} and ${subnet}.254" >&2; err=true; printf '\e[s'; }
        query-reset
    done
}

query-dhcp-lease() {
    local err=false
    printf '\n'
    while dhcp_lease=$(query "Enter a dhcp lease time (1-999999)[h|m|s|] :"); do
        if [[ $dhcp_lease =~ ^[1-9][0-9]{0,5}[hms]$ ]]; then
            printf '\e[J'
            break
        fi
        [[ $err == true ]] || { printf "\e[u\e[K$fmt_warn" "Please enter a valid lease time (1-999999)(h|m|s)..." >&2; err=true; printf '\e[s'; }
        query-reset
    done
}

confirm-settings() {
    cat <<EOF >&2
WAN Interface    : ${wan_if}
LAN Interface    : ${lan_if}
LAN ipv4 Address : ${lan_ip}
DHCP Pool Start  : ${dhcp_start}
DHCP Pool End    : ${dhcp_end}
DHCP Lease Time  : ${dhcp_lease}

EOF

    while response=$(query "Are these settings correct? [Y|n] "); do
        response="${response:-y}"
        if [[ $response =~ [YyNn] ]]; then
            case "${response,,}" in
                y) return 0;;
                n) return 1;;
            esac
        fi
        query-reset
    done
}

populate-settings-query() {
    command -v nordvpn &>/dev/null || { printf "$fmt_error" "NordVPN app is not found on this system"; exit 9; }
    local key value
    while IFS=":" read -r key value; do
        if [[ $value  =~ (enabled) ]]; then
            value="on"
        elif [[ $value =~ (disabled) ]]; then
            value="off"
        else
            value="off"
        fi
        if [[ -n "${nord_settings_template[$key]}" ]]; then
            nord_settings_connector["$key"]="$value"
            nord_settings_actor["${nord_settings_template[$key]}"]="$value"
        fi
    done < <(nordvpn settings)
}

get-nord-settings() {
    while :; do
        clear
        printf "\n$fmt_menu_header\n" "Choose NordVPN Settings" >&2
        local -a index
        local j=0
        for item in "${!nord_settings_template[@]}"; do
            index+=("$item")
            menuitem-status "$j" "${nord_settings_actor[${nord_settings_template[$item]}]}" "$item"
            ((j++))
        done
        while response=$(query "Choose a setting to change, or [q] to finish :"); do
            [[ $response =~ [Qq] ]] && return
            if [[ $response =~ ^[0-9]+$ ]] && [[ $response -lt ${#index[@]} ]]; then
                local setting_key="${nord_settings_template[${index[$response]}]}"
                if [[ ${nord_settings_actor[$setting_key]} =~ "on" ]]; then
                    nord_settings_actor[$setting_key]="off"
                elif [[ ${nord_settings_actor[$setting_key]} =~ "off" ]]; then
                    nord_settings_actor[$setting_key]="on"
                fi
                break
            fi
        done
    done
}

apply-nord-settings() {
    printf "$fmt_info" "Applying NordVPN settings"
    working-dots & dots_pid=$!
    for setting in "${!nord_settings_actor[@]}"; do
        nordvpn set "$setting" "${nord_settings_actor[$setting]}"
    done
    update-dots finish
}

perform-nord-installation() {
    printf "$fmt_working" "Installing NordVPN"
    working-dots & dots_pid=$!
    bash < <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh) -s -- -n &>/dev/null || { printf "$fmt_error" "Failed to install NordVPN application!"; exit 8; }
    update-dots finish
}

login-nord() {
    while :; do
        while :; do
            read -ra nord_redirect_url < <(nordvpn login)
            if [[ ${nord_redirect_url[*]} =~ (You are already logged in) ]]; then
                printf "$fmt_info" "You are logged in"
                return 0
            fi
            if [[ ${nord_redirect_url[*]} =~ (login-redirect) ]]; then
                nord_login_url="${nord_redirect_url[-1]}"
                break
            fi
            sleep 2
        done
        clear
        /usr/bin/cat <<EOF

    $(printf ${c_grn})===== NordVPN Login =====$(printf ${c_rst})

    $(printf '\e[4m')Instructions:$(printf ${c_rst})

        1) Open this link in your browser:

            $(printf ${c_cyn})${nord_login_url}$(printf ${c_rst})

        2) Login.
        3) Cancel any request to open a new window.
        4) Right-click on the 'Continue' button and copy the link.
        5) Paste the link here$(printf '\e[s')
EOF
        printf '\e[u'
        nord_callback_url=$(query ">> ")

        nordvpn login --callback "$nord_callback_url" && { printf "$fmt_info" "Login successful!"; return 0; }

        printf "$fmt_warn" "Try again..."
        sleep 1.5
    done
}

configure-monitor-service() {
    country=
    group=
    local set_options=false
    clear
    while response=$(query "Do you want to configure connection options like country or group (p2p, tor, etc.)? [y|N] "); do
        if [[ $response =~ [YyNn] ]]; then
            response="${response:-n}"
            case "${response,,}" in
                y) set_options=true; break;;
                n) break;;
            esac
        fi
        query-reset
    done
    if [[ $set_options == true ]]; then
        ### COUNTRY
        local max_len=0
        local -a countries
        mapfile -t countries < <(nordvpn countries | xargs -n1)
        for country in "${countries[@]}"; do
            [[ ${#country} -gt $max_len ]] && max_len=${#country}
        done
        export menu_col_width=$((max_len+3))
        for (( i=0; i<${#countries[@]}; i++ )); do
            (( (i+1) % 3 == 0 )) && flag="" || flag="__NO__"
            menuitem "$i" "${countries[$i]}" "$flag"
        done
        menuitem "q" "NONE"
        while response=$(query "Select a country, or Q for none : "); do
            [[ ${response,,} == "q" ]] && { country=""; break; }
            if [[ $response =~ ^[0-9]+$  && $response -lt ${#countries[@]} ]]; then
                country="${countries[$response]}"
                break
            fi
            query-reset
        done
        ### GROUP
        local max_len=0
        local -a groups
        mapfile -t groups < <(nordvpn groups | xargs -n1)
        for group in "${groups[@]}"; do
            [[ ${#group} -gt $max_len ]] && max_len=${#group}
        done
        (( max_len + 3 ))
        export menu_col_width=$max_len
        for (( i=0; i<${#groups[@]}; i++ )); do
            (( (i+1) % 3 ==0 )) && flag="" || flag="__NO__"
            menuitem "$i" "${groups[$i]}" "$flag"
        done
        menuitem "q" "NONE"
        while response=$(query "Select a group, or Q for none : "); do
            [[ ${response,,} == "q" ]] && { group=""; break; }
            if [[ $response =~ ^[0-9]+$  && $response -lt ${#groups[@]} ]]; then
                group="${groups[$response]}"
                break
            fi
            query-reset
        done
    else
        country=""
        group=""
    fi
    install-monitor-service
}

install-monitor-service() {
    ### need to fetch file
    printf "$fmt_working" "Fetching service files"
    working-dots &
    dots_pid=$!
    wget -qO /etc/systemd/system/nordvpn-net-monitor.service https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/nordvpn-net-monitor.service || { printf "$fmt_error" "Failed to fetch nordvpn-net-monitor.service"; exit 10; }
    wget -qO /root/connect-nord.sh https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/connect-nord.sh || { printf "$fmt_error" "Failed to fetch connect-nord.sh"; exit 11; }
    wget -qO /root/connect-nord.conf https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/cli-script/connect-nord.conf || { printf "$fmt_error" "Failed to fetch connect-nord.conf"; exit 12; }
    update-dots finish
    printf "$fmt_working" "Configuring files"
    working-dots &
    dots_pid=$!
    chmod +x /root/connect-nord.sh &> /dev/null
    # need to update connect-nord.conf to reflect new placeholder patterns "__WAN_IF__" and "__LAN_IF__"
    sed -i "s/wan_interface/$wan_if/g" /root/connect-nord.conf &> /dev/null
    sed -i "s/lan_interface/$lan_if/g" /root/connect-nord.conf &> /dev/null
    if [[ -n $group || -n $country ]]; then
        if [[ -n $group && -n $country ]]; then
            connect_options="-g ${group} ${country}"
        else
            connect_options="${group}${country}"
        fi
        sed -i "s/c_options/$connect_options/g" /root/connect-nord.conf
    else
        sed -i "s/c_options//g" /root/connect-nord.conf
    fi
    update-dots finish
    printf "$fmt_working" "Enabling service"
    working-dots &
    dots_pid=$!
    systemctl daemon-reload &> /dev/null
    systemctl enable nordvpn-net-monitor.service &> /dev/null
    update-dots finish
}

restart-services() {
    printf "$fmt_info" "Restarting services and applying network changes"
    printf "$fmt_working" "nftables"
    working-dots &
    dots_pid=$!
    systemctl restart nftables &> /dev/null
    printf "\n$fmt_working" "dnsmasq"
    systemctl restart dnsmasq &> /dev/null
    update-dots gonext
    printf "\n$fmt_working" "network"
    systemctl restart networking &> /dev/null
    update-dots finish
}
### RUN IT
if [[ $EUID -ne 0 ]]; then
    printf "$fmt_error" "This script must be run as root or sudo"
    exit 1
fi

clear
/usr/bin/cat <<EOF

$(printf ${c_grn})This will setup this system as a router, either simple or for NordVPN. The installation
process will install the following packages if not already installed:
$(printf ${c_blu})
    dnsmasq nftables
$(printf ${c_rst})


EOF

while response=$(query "Do you wish to continue? [Y|n] "); do
    response="${response:-y}"
    if [[ $response =~ [YyNn] ]]; then
        case "${response,,}" in
            y) break;;
            n) exit 1;;
        esac
    fi
    query-reset
done

### UPDATE SYSTEM AND INSTALL PACKAGES
apt update || { printf "$fmt_error" "Failed to update apt"; exit 2; }
apt upgrade -y || { printf "$fmt_error" "Failed to update system"; exit 3; }
apt install "${apt_packages[@]}" -y || { printf "$fmt_error" "Failed to install required packages"; exit 4; }

### populate available network interfaces
for iface in /sys/class/net/*; do
    iface=$(basename "$iface")
    if [[ $iface =~ ^(eno|eth|enp|ens) ]]; then
        net_interfaces+=("$iface")
        net_interface_pool["$iface"]=""
    fi
done

### validate interface count
[[ ${#net_interfaces[@]} -lt 2 ]] && { printf "$fmt_error" "Not enough network interfaces."; exit 4; }

query-router-mode
[[ $not_nord == true ]] && printf "$fmt_info\n" "Setting up as a simple router." || printf "$fmt_info\n" "Setting up as a NordVPN router"

while :; do
    clear
    while :; do
        query-wan-interface
        [[ -n $lan_if && -n $wan_if && $wan_if != $lan_if ]] && break
        query-lan-interface
        [[ -n $lan_if && -n $wan_if && $wan_if != $lan_if ]] && break
    done

    clear
    while ! query-lan-address; do :; done
    while ! query-dhcp-start; do :; done
    while ! query-dhcp-end; do :; done
    while ! query-dhcp-lease; do :; done

    confirm-settings && break
done
get-files
write-files
if [[ $not_nord == false ]]; then
    perform-nord-installation || { printf "$fmt_error" "Error installing NordVPN application."; exit 5; }
    populate-settings-query
    get-nord-settings
    apply-nord-settings
    login-nord || { printf "$fmt_error" "Error logging into NordVPN"; exit 6; }
    while response=$(query "Do you want to install the systemd monitor service? [Y|n] "); do
        response="${response:-y}"
        if [[ $response =~ [YyNn] ]]; then
            if [[ $response =~ [Yy] ]]; then
                configure-monitor-service
                break
            fi
        fi
        query-reset
    done
    while response=$(query "Do you want to install the webui? "); do
        response="${response:-y}"
        if [[ $response =~ [YyNn] ]]; then
            if [[ $response =~ [Yy] ]]; then
                if bash < <(wget -qO - https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/webui/setup-webui.sh); then
                    printf "$fmt_info" "You can access the webui at: https://${lan_ip}:1776"
                else
                    printf "$fmt_warn" "Error installing webui. Non-critical error"
                fi
                break
            else
                break
            fi
        fi
        query-reset
    done
fi

restart-services

printf "$fmt_info" "Router setup complete!"

query "Press [enter] to reboot..."

printf "\e[?25l${c_grn} Rebooting in\e[s %d seconds...${c_rst}" 5
for i in {5..1}; do
    printf "${c_wht}\e[u %d ${c_rst}" $i
    sleep 1
done
printf "\r\e[J%s\e[?25h" "REBOOTING NOW!"

sleep 1

shutdown -r now
