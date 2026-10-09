#!/bin/sh
# Wake the UPERFECT monitor over DDC/CI (HDMI) if it is in standby.
st=$(ddcutil --sleep-multiplier 0.5 getvcp D6 --brief 2>/dev/null)
case "$st" in *x01*) exit 0 ;; esac
logger -t uperfect-wake "monitor in standby ($st), sending D6=1"
ddcutil setvcp D6 0x01
