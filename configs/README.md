# Brief Setup

**OS**: Raspberry Pi OS 11 (bullseye) Lite 64-bit 2022-04-04 5.15.32-v8+

## Load the OS

Load latest recovery/EEPROM (optional)

Use Imager to load Raspberry Pi OS onto the Compute Module 4 (or SD card).

Open `/boot/config.txt` and enter the following lines:

```
# Speedup the boot process
force_eeprom_read=0
disable_poe_fan=1
boot_delay=0
initial_turbo=10
start_cd=1

# Reduce GPU frequency to save power
# core_freq_min and gpu_freq_min are the only options that seem to have any effect on idle power consumption
core_freq_min=60
gpu_freq_min=60

# https://github.com/raspberrypi/firmware/blob/master/boot/overlays/README

# Disable bluetooth
dtoverlay=disable-bt

# Enable I2C for BME280 sensor and DS3231 RTC
dtparam=i2c_vc=on
dtoverlay=i2c1
dtoverlay=i2c-sensor,bme280,addr=0x76
dtoverlay=i2c-rtc,ds3231

# Shutdown button
dtoverlay=gpio-shutdown,gpio_pin=4

# Use external WiFi antenna
dtparam=ant2

# Setting 'pwr_led_trigger' to 'cpu' causes excessive CPU usage, but using 'act_led_trigger' works fine
# 'cpu' doesn't work with 64-bit kernel https://github.com/raspberrypi/linux/issues/4425
dtparam=act_led_trigger=cpu
dtparam=pwr_led_trigger=mmc0

# https://diode.io/raspberry%20pi/running-forever-with-the-raspberry-pi-hardware-watchdog-20202/
#dtparam=watchdog=on

# Set GPU memory to 32MB
# Can go down to 16MB, but some errors will appear in dmesg during boot. They're not a problem, though.
gpu_mem=32
#hdmi_enable_4kp60=1
```

**BOOT**

Once you've logged in the first thing to do is to stop the boot process from hanging if it takes a while to get an IP:

```
sudo raspi-config

	1 System Options ->
		S6 Network at Boot ->
			No
```

## Disable swapfile

Router things don't use much RAM so no need for swap. Disabling the swapfile can help reduce the number of writes to flash in case the kernel does decide to move some stuff into it.

```
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo systemctl disable dphys-swapfile
```

**REBOOT**

## Update Packages

```
sudo apt update
sudo apt dist-upgrade
sudo apt upgrade
```

## Install Packages

|Package|What it's for|
|---|---|
|ppp|PPPoE ISP connections|
|vlan|VLAN ISP connections|
|bind9|Recursive DNS resolver|
|ifplugd|Run scripts when a network cable is plugged/unplugged|
|bc|Maths stuff in bash scripts|
|pigpio, python-pigpio|GPIO things for playing beep tunes|

```
sudo apt install ppp vlan bind9 dnsutils ifplugd bc pigpio python-pigpio
```

By default, pigpio has polling enabled which tends to use a lot of CPU time and since we're not using that feature we can disable it.
Also, pigpio sometimes gets stuck at shutdown and the default timeout is 90 seconds. This needs to be changed to something a bit shorter.

```
sudo systemctl edit --full pigpiod.service
```

Disable polling:  
Add ` -m` option to the `ExecStart` line, like: `ExecStart=/usr/bin/pigpiod -l -m`

Shorten timeout:  
Add a new line containing `TimeoutStopSec=5` in the `[Service]` section.

`CTRL + X` then `y` to save.

Enable pigpio daemon:
```
sudo systemctl enable pigpiod
```

## Configure Network

See `/etc/dhcpd.conf`, `/etc/network/interfaces.d/pppvlan` and `/etc/ppp/`

|Interface|Config|
|---|---|
|eth0 (LAN)|Static 10.0.0.1 / 24|
|eth1 (WAN)|Static 10.0.1.1 / 24|
|eth1.101|VLAN with DHCP/PPP - This will depend on your ISP|

This is where you will need to try and get the Pi to connect to your ISP!

Enable forwarding by uncommenting `net.ipv4.ip_forward` in `/etc/sysctl.conf` and make sure it is set to `1`.

## Configure Packages

See configuration files in:

`/etc/bind/`  
`/etc/default/`  
`/etc/ifplugd/`  
`/etc/ssh/`

Copy `/scripts/` onto your Pi and add `/scripts/onboot.sh` to `/etc/rc.local`.

## Install Pi-hole

Pi-hole will be configured to forward non-blocked DNS queries to BIND listening on port 5353. Pi-hole also deals with DHCP.

```
curl -sSL https://install.pi-hole.net | sudo bash
```

* Select the LAN interface (probably eth0) at the "Choose An Interface" page
* Select Custom (at the bottom) at the "Select Upstream DNS Provider" page
* Enter `127.0.0.1#5353` on the "Desired upstream DNS provider" page
* Select `No` for logging queries (optional, it just reduces the number of writes to flash)

Add `DBINTERVAL=60` to `/etc/pihole/pihole-FTL.conf` to further reduce number of flash writes.

Configure DHCP, see `/etc/dnsmasq.d/router-dhcp.conf`.

## Clean Up

```
sudo apt autoremove
```

## Stop Unnecessary Services

|Service|What it does|
|---|---|
|avahi-daemon|Apple mDNS|
|triggerhappy|Hotkey daemon|
|systemd-timesyncd|Network time sync. Keep enabled if you're not using an RTC|
|rsyslog|Logging, disable to reduce flash writes since there's already `journald`|
|phpsessionclean|a|
|apt-daily|Auto-updates|
|apt-daily-upgrade|Auto-updates|
|man-db|Auto-generate manuals DB|

When auto-updates are disabled you will have to manually check for updates every now and then, but it saves the headache of waking up one morning to find that DNS or something has stopped working because an update got messed up.

```
sudo systemctl stop avahi-daemon triggerhappy systemd-timesyncd.service rsyslog
sudo systemctl disable avahi-daemon triggerhappy systemd-timesyncd.service rsyslog
sudo systemctl stop phpsessionclean.timer apt-daily.timer apt-daily-upgrade.timer man-db.timer
sudo systemctl disable phpsessionclean.timer apt-daily.timer apt-daily-upgrade.timer man-db.timer
```

**REBOOT**

Done!
