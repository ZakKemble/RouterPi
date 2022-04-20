#!/usr/bin/python

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

import sys
import pigpio
import time

PIN = 18
DUTY = 500000

pi = pigpio.pi()

def validInt(s):
	try: 
		int(s)
		return True
	except ValueError:
		return False

if __name__ == "__main__":
	for i, arg in enumerate(sys.argv):
		config = arg.split("-", 2)
		count = len(config)
		
		if validInt(config[0]) == False:
			continue

		freq = int(config[0])
		
		if freq > 20000 or freq < 50:
			continue

		if count > 1:
			duration = int(config[1])
		else:
			duration = 1000

		if count > 2:
			delay = int(config[2])
		else:
			delay = 0

		#print freq, " - ", duration, " - ", delay

		pi.hardware_PWM(PIN, freq, DUTY)
		time.sleep(duration / 1000.0)
		if delay > 0:
			pi.hardware_PWM(PIN, 0, 0)
			time.sleep(delay / 1000.0)

	pi.hardware_PWM(PIN, 0, 0)
