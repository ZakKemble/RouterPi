#!/bin/bash

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

TUNE=$1

if [ -z "${TUNE}" ]; then
    echo "No argument supplied"
	exit 1
fi

declare -A TUNES
TUNES=(
	[boot]="3000-300-50 5000-500"
	[pppup]="3000-300-50 3000-100-100 5000-500"
	[pppdown]="5000-300-50 5000-100-100 3000-500"
	[ethlinkup]="3000-100-50 4000-100-50 5000-200"
	[ethlinkdown]="5000-100-50 4000-100-50 3000-200"
)

if ! [ ${TUNES[${TUNE}]+exists} ]; then
	echo "Unknown tune: ${TUNE}"
	exit 1
fi

/scripts/beep.py ${TUNES[${TUNE}]}

exit 0
