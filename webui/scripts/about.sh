#!/usr/bin/env bash
IFS=":" read -r key value < <(nordvpn version)

echo "${value}"
