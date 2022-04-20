#!/bin/bash

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

# Stuff to do at boot

cd /scripts

./tunes.sh boot &

# Configure CPU affinity for network interface interrupts
readarray -t ETH_IRQS <<<$(cat /proc/interrupts | grep eth0 | sed "s/^ \([0-9]\+\).*/\1/")
echo 2 | sudo tee /proc/irq/${ETH_IRQS[0]}/smp_affinity
echo 4 | sudo tee /proc/irq/${ETH_IRQS[1]}/smp_affinity

# Configure CPU affinity for packet queues
echo 8 | sudo tee /sys/class/net/eth1/queues/rx-0/rps_cpus

# Load NAT/firewall rules
./firewall.sh

echo "BOOT: $(date +%s) $(date)" > /dev/kmsg
