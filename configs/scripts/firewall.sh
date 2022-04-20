#!/bin/bash

# Project: RouterPi
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# License: 
# Web: https://blog.zakkemble.net/routerpi-compute-module-4-router/

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
. ${DIR}/colours

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}This script must be run as root${NC}" 
	exit 1
fi

echo -e "${CYAN}<<<<< Setting IPTABLES firewall & NAT >>>>>${NC}"

LAN=$1
WAN=$2
MODEM=$3

[ ! -n "$LAN" ] && LAN="eth0"
[ ! -n "$MODEM" ] && MODEM="eth1"
[ ! -n "$WAN" ] && WAN="eth1.101"

WAN_IN_USE=$WAN

SERVER=10.0.0.2

echo -e "LAN: ${RED}${LAN}${NC}"
echo -e "WAN: ${RED}${WAN_IN_USE}${NC}"
echo -e "MODEM: ${RED}${MODEM}${NC}"
echo -e "Server: ${RED}${SERVER}${NC}"

# Common ports
PORT_SSH=22
PORT_SMTP=25
PORT_SMTPS=465
PORT_SUBMISSION=587
PORT_HTTP=80
PORT_HTTPS=443
PORT_FTP=21
PORT_FTPS=990
PORT_DNS=53
PORT_DHCP=67
PORT_RDP=3389
PORT_POP3=110
PORT_POP3S=995
PORT_IMAPS=993
PORT_IMAP=143

CHAIN_FRWD_FW="FRWD_FW"
CHAIN_FRWD_NAT="FRWD_NAT"

chainBogons()
{
	echo -e "Creating chain: ${RED}Bogons${NC}"
	iptables -N BOGONS

	iptables -A BOGONS -s 10.0.0.0/8 -j DROP
	iptables -A BOGONS -s 127.0.0.0/8 -j DROP
	iptables -A BOGONS -s 128.0.0.0/16 -j DROP
	iptables -A BOGONS -s 169.254.0.0/16 -j DROP
	iptables -A BOGONS -s 172.16.0.0/12 -j DROP
	iptables -A BOGONS -s 191.255.0.0/16 -j DROP
	iptables -A BOGONS -s 192.0.0.0/24 -j DROP
	iptables -A BOGONS -s 192.0.2.0/24 -j DROP
	iptables -A BOGONS -s 192.168.0.0/16 -j DROP
	iptables -A BOGONS -s 198.18.0.0/15 -j DROP
	iptables -A BOGONS -s 198.51.100.0/24 -j DROP
	iptables -A BOGONS -s 203.0.113.0/24 -j DROP
	iptables -A BOGONS -s 223.255.255.0/24 -j DROP
	iptables -A BOGONS -s 224.0.0.0/4 -j DROP
	iptables -A BOGONS -s 240.0.0.0/4 -j DROP
	iptables -A BOGONS -s 255.255.255.255/32 -j DROP
}

chainForwardAdd()
{
	local IP=$1
	local PROTO=$2
	local PORT=$3
	local EXTRA=$4

	local TOPORT=$(echo -n "$PORT" | tr ":" "-")

	iptables -t nat -A $CHAIN_FRWD_NAT -p $PROTO --dport $PORT -j DNAT --to $IP:$TOPORT $EXTRA
	iptables -A $CHAIN_FRWD_FW -d $IP -p $PROTO --dport $PORT -j ACCEPT $EXTRA
}

chainForwardAllow()
{
	echo -e "Creating chain: ${RED}Forward firewall & NAT${NC}"
	iptables -N $CHAIN_FRWD_FW
	iptables -t nat -N $CHAIN_FRWD_NAT

	# Example: Forward ports 80 and 443 to 10.0.0.2
#	chainForwardAdd $SERVER tcp $PORT_HTTP
#	chainForwardAdd $SERVER tcp $PORT_HTTPS
}

allowEstablished()
{
	local CHAIN=$1
	iptables -A $CHAIN -m state --state ESTABLISHED,RELATED -j ACCEPT
}

createInterfaceFWChains()
{
	local IFACE=$1

	iptables -N INPUT_$IFACE
	iptables -N FRWD_$IFACE

	iptables -A INPUT -i $IFACE -j INPUT_$IFACE
	iptables -A FORWARD -i $IFACE -j FRWD_$IFACE
}

createInterfaceNATChains()
{
	local IFACE=$1

	iptables -t nat -N PREROUTE_$IFACE
	iptables -t nat -N POSTROUTE_$IFACE

	iptables -t nat -A PREROUTING -i $IFACE -j PREROUTE_$IFACE
	iptables -t nat -A POSTROUTING -o $IFACE -j POSTROUTE_$IFACE
}

NATDynamic()
{
	local IFACE=$1

	# Dont use source port randomization, causes too many problems with poorly coded games
	# Still keep it enabled for DNS though

	iptables -t nat -A POSTROUTE_$IFACE -p udp --dport $PORT_DNS -j MASQUERADE --random
	iptables -t nat -A POSTROUTE_$IFACE -j MASQUERADE
}

setLANstuff()
{
	local IFACE=$1
	echo -e "Configuring LAN interface: ${RED}$IFACE${NC}"

	createInterfaceFWChains $IFACE

	# Allow established things
	allowEstablished INPUT_$IFACE

	iptables -A INPUT_$IFACE -p udp --dport $PORT_DNS -j ACCEPT
	iptables -A INPUT_$IFACE -p udp --dport $PORT_DHCP -j ACCEPT
	iptables -A INPUT_$IFACE -p tcp --dport $PORT_SSH -j ACCEPT
	#iptables -A INPUT_$IFACE -i $IFACE -j ACCEPT # Allow all from LAN -> FW

	iptables -A INPUT_$IFACE -p icmp --icmp-type echo-request -m state --state NEW -j ACCEPT # Ping

	# Block DNS apart from 8.8.8.8 and 8.8.4.4
	iptables -A FRWD_$IFACE -p udp --dport $PORT_DNS -d 8.8.8.8,8.8.4.4 -j ACCEPT
	iptables -A FRWD_$IFACE -p udp --dport $PORT_DNS -j DROP

	# End
	iptables -A INPUT_$IFACE -j DROP
	iptables -A FRWD_$IFACE -j ACCEPT # Allow all from LAN -> *
}

logBlocked()
{
	local IFACE=$1
	echo -e "Logging blocked for: ${RED}$IFACE${NC}"
	iptables -A INPUT -i $IFACE -j LOG --log-level 4 --log-prefix "iptables: "
}

# Allows all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
setLocalStuff()
{
	echo "Local stuff..."
	iptables -A INPUT ! -i lo -d 127.0.0.0/8 -j DROP
	iptables -A INPUT -i lo -j ACCEPT
	#iptables -A OUTPUT -o lo -j ACCEPT # Not needed because OUTPUT default is ACCEPT already
}

setWANstuff()
{
	local IFACE=$1
	echo -e "Configuring WAN interface: ${RED}$IFACE${NC}"

	createInterfaceFWChains $IFACE
	createInterfaceNATChains $IFACE

	# NAT
	NATDynamic $IFACE
	iptables -t nat -A PREROUTE_$IFACE -j $CHAIN_FRWD_NAT # Forwarding

	# Bogons
	iptables -A INPUT_$IFACE -j BOGONS
	iptables -A FRWD_$IFACE -j BOGONS

	# Allow established things
	allowEstablished INPUT_$IFACE
	allowEstablished FRWD_$IFACE

	# Firewall allow NAT forwarding
	iptables -A FRWD_$IFACE -o $LAN -j $CHAIN_FRWD_FW

	# End
	iptables -A INPUT_$IFACE -j DROP
	iptables -A FRWD_$IFACE -j DROP
}

setModemStuff()
{
	local IFACE=$1
	echo -e "Configuring modem interface: ${RED}$IFACE${NC}"

	createInterfaceFWChains $IFACE
	createInterfaceNATChains $IFACE

	# NAT
	NATDynamic $IFACE

	# Allow established things
	allowEstablished INPUT_$IFACE
	allowEstablished FRWD_$IFACE

	iptables -A INPUT_$IFACE -p icmp --icmp-type echo-request -m state --state NEW -j ACCEPT # Ping

	# End
	iptables -A INPUT_$IFACE -j DROP
	iptables -A FRWD_$IFACE -j DROP
}

# Flush all current rules from iptables and set default policies
iptables -P INPUT DROP # Default drop incoming packets
iptables -P OUTPUT ACCEPT # Allow all from FW -> *
iptables -P FORWARD DROP # Default drop forwarding packets
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -t nat -X
iptables -t mangle -X
iptables -Z

# New chains
chainBogons
chainForwardAllow

# NAT reflection?

setWANstuff $WAN_IN_USE
setLANstuff $LAN
setModemStuff $MODEM
#logBlocked $WAN
setLocalStuff

# Set correct MSS
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o $WAN_IN_USE -j TCPMSS --clamp-mss-to-pmtu

# Enable forwarding (already done in /etc/sysctl.conf)
#echo 1 > /proc/sys/net/ipv4/ip_forward

echo -e "${CYAN}<<<<< IPTABLES firewall & NAT completed >>>>>${NC}"
exit 0
