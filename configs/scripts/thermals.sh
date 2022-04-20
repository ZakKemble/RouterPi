#!/bin/bash

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

# https://www.raspberrypi.org/forums/viewtopic.php?t=34994#p322056

# Use 'vcgencmd measure_temp' isntead of 'cat /sys/class/thermal/thermal_zone0/temp'
# https://raspberrypi.stackexchange.com/questions/105811/measuring-the-cpu-temp-and-gpu-temp-in-bash-and-python-3-5-3-pi-2-3b-3b-4b

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
. ${DIR}/colours

TEMP_CPU=$(vcgencmd measure_temp | awk -F "=|'" '{print $2}')
TEMP_PMIC=$(vcgencmd measure_temp pmic | awk -F "=|'" '{print $2}')
TEMP_RTC=$(cat /sys/bus/i2c/devices/i2c-1/1-0068/hwmon/hwmon2/temp1_input)
TEMP_BME=$(cat /sys/bus/i2c/devices/i2c-1/1-0076/iio\:device0/in_temp_input)
HUM_BME=$(cat /sys/bus/i2c/devices/i2c-1/1-0076/iio\:device0/in_humidityrelative_input)
PRES_BME=$(cat /sys/bus/i2c/devices/i2c-1/1-0076/iio\:device0/in_pressure_input)

TEMP_RTC=$(bc <<< "scale=2; ($TEMP_RTC / 1000)")
TEMP_BME=$(bc <<< "scale=2; ($TEMP_BME / 1000)")
HUM_BME=$(bc <<< "scale=2; ($HUM_BME / 1000)")
PRES_BME=$(bc <<< "scale=2; ($PRES_BME * 10)/1")

echo -e "${CYAN}CPU:${NC}\t\t${TEMP_CPU}\xc2\xb0C"
echo -e "${CYAN}PMIC:${NC}\t\t${TEMP_PMIC}\xc2\xb0C"
echo -e "${CYAN}RTC:${NC}\t\t${TEMP_RTC}\xc2\xb0C"
echo -e "${CYAN}Ambient:${NC}\t${TEMP_BME}\xc2\xb0C"
echo -e "\t\t${HUM_BME}%"
echo -e "\t\t${PRES_BME} hPa"

exit 0
