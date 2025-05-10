#!/usr/bin/env bash

help() {
    cat <<EOF

Usage: get-nord.sh command [-o]

    Commands:
        account         Get current account information
        status          Get current nordvpn status
        settings        Get current nordvpn settings

    Command options:
        -o              (Optional) Obfuscate email address. Only useful with account


EOF
}

true=1
false=0
args=
obfuscate_email=$false
while (( "$#" )) ; do
    case "$1" in
        -o)
            obfuscate_email=$true
            shift
            ;;
        status|settings|account)
            args=$1 
            shift
            ;;
        -h|--help)
            help
            exit 1
            ;;
        *) 
            echo "Unknown parameter. Exiting with error."
            exit 2
            ;;
    esac
done

glob="{"
while IFS=":" read -r key value ; do
    if [[ $key =~ (Email) && $obfuscate_email == $true ]] ; then value="********"; fi
    value=$(xargs <<< "${value}")
    key="${key// /_}"
    glob+="\"$key\": \"$value\","
done < <(nordvpn "$args")
glob=${glob::-1} # erase last comma
glob+="}"

echo "${glob}"
