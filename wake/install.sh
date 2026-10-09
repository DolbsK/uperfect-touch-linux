#!/bin/sh
# Install the DDC/CI wake timer. Run as root from this folder.
set -e
apt-get install -y ddcutil
echo i2c-dev > /etc/modules-load.d/i2c-dev.conf
modprobe i2c-dev
install -m 755 uperfect-wake.sh /usr/local/bin/uperfect-wake.sh
install -m 644 uperfect-wake.service uperfect-wake.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now uperfect-wake.timer
ddcutil getvcp D6
