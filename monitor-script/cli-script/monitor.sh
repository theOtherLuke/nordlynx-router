#!/usr/bin/env bash
license(){
    clear
    cat <<EOF
MIT License

Copyright (c) 2024 nodaddyno

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
}

license
sleep 1

echo -e "\e[?25l"
main_pid="$$"
true=0
false=1
status_items="account settings status" # change this to only show what you want to see
hide_email=$true
email_mask="********"
updater_pid=

cleanup() {
    kill "$updater_pid"
    echo -e "\e[?25h\e[0m"
    clear
    exit
}

declare -A current_updates=(
    ["status"]=0
    ["settings"]=0
    ["account"]=0
)

declare -a stats=(
    "Created"
    "No Change"
    "Updated"
    "Error"
)

declare -a status_colors=(
    '\e[1;34m'
    '\e[1;35m'
    '\e[1;36m'
    '\e[1;31m'
)

retrieve() {
    ref_items="$1"
    ref_changes="${1}_changes"
    items_changed=$false
    first_run=$false

    ### setup arrays
    declare -n items=$ref_items
    if [[ -z ${items[*]} ]] ; then
        declare -gA "${ref_items}"
        first_run=$true
    fi
    declare -n changes=$ref_changes
    if [[ -z ${items[*]} ]] ; then
        declare -gA "${ref_changes}"
        first_run=$true
    fi

    ### read values into items[] and do stuff
    while IFS=":" read -r key value ; do
        value="$(xargs <<< "$value")"

        ### logic for connection status
        if [[ $ref_items =~ (status) ]] && [[ $key =~ (Status) ]] && [[ $value =~ (Disconnected) ]] ; then
            unset items[]
            items["$key"]="$value"
            changes["$key"]=3
            items_changed=$true
            break
        fi

        ### logic for basic updating of arrays
        if [[ $key =~ ([E|e]mail) ]] && [[ $hide_email == $true ]] ; then
            value="$email_mask"
        fi
        if [ ! "${items["$key"]}" == "$value" ] ; then # test if value is changed
            items["$key"]="$value" # assign new value to key
            if [[ $key =~ (Analytics) ]] && [[ $value =~(enabled) ]] ; then
                changes["$key"]=3
            else
                changes["$key"]=2 # mark as changed
            fi
            items_changed=$true # notify caller of update
        else
            if [[ $key =~ (Analytics) ]] && [[ $value =~(enabled) ]] ; then
                changes["$key"]=3
            else
                changes["$key"]=1 # mark as changed
            fi
        fi
    done < <(nordvpn "$ref_items")

    ### set indicator for changes to items[]
    if [[ "$first_run" == "$true" ]] ; then
        return $false
    else
        if [[ "$items_changed" == "$true" ]] ; then
            current_updates["$ref_items"]=2
        else
            current_updates["$ref_items"]=1
        fi
        return $items_changed
    fi
}

display() {
    declare -n items="$1"
    declare -n changes="${1}_changes"
    for name in "${!items[@]}" ; do # iterate through keys in the array
#        echo -e "${name}\e[35G: ${status_colors[${changes["$name"]}]} ${items["${name}"]}\e[0m"
        printf "%35s : ${status_colors[${changes[$name]}]}%-25s\e[0m\n" "${name}" "${items[$name]^}"
    done
}

trap-keyboard() {
    while :; do
        read -srn1 result
        result="${result,,}"
        case "$result" in
            q)
                echo "Exiting..."
                exit
                ;;
            *) ;;
        esac
    done
}

main() {
    while :; do
        read -ra update_items <<< "$1"
        for status_item in "${update_items[@]}" ; do
            retrieve "$status_item"
        done
        clear
        echo -e "\e[1;32m[ $(date +%F" "%T) ]\e[0m"
        for status_item in "${update_items[@]}" ; do
            echo
#            echo -e "\e[1;32m${status_item^} : ${status_colors[${current_updates["$status_item"]}]}${stats[${current_updates["$status_item"]}]}\e[0m"
            printf "\e[1;32m%35s : ${status_colors[${current_updates[$status_item]}]}%-25s\e[0m\n" "${status_item^}" "${stats[${current_updates[$status_item]}]}"
            display "$status_item"
        done
        sleep 5
    done & updater_pid="$!"
    trap-keyboard
}

trap cleanup SIGINT INT SIGTERM EXIT

main "$status_items"
