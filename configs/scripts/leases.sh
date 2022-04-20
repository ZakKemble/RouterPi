#!/bin/bash

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
. ${DIR}/colours

IN=$(cat /var/lib/misc/dnsmasq.leases)

NOW=$(date +%s)

echo -e "${CYAN}IP          \t${GREEN}HOST NAME           \t${RED}MAC              \t${PURPLE}EXPIRES IN\t${ORANGE}HOST ID"

while IFS=' ' read -ra PARTS; do
	TIMELEFT=$(((${PARTS[0]} - ${NOW}) / 60))
	TIMELEFT_HR=$((${TIMELEFT} / 60))
	TIMELEFT=$((${TIMELEFT} % 60))
	#TIMELEFT=$(bc <<< "scale=1; ((${PARTS[0]} - ${NOW}) / 60 / 60)")
	printf "${CYAN}%-12s\t${GREEN}%-20s\t${RED}%-17s\t${PURPLE}%-10s\t${ORANGE}%s\n" "${PARTS[2]}" "${PARTS[3]}" "${PARTS[1]^^}" "${TIMELEFT_HR}:${TIMELEFT} hrs" "${PARTS[4]}"
done <<< "$IN"

exit 0
