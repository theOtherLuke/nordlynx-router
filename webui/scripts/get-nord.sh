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
