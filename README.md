# UPERFECT portable touch monitor on Linux / Raspberry Pi

How to make the touchscreen of a UPERFECT 15.6" portable monitor work on Linux,
including Raspberry Pi 4 and Pi 5, when it works on Windows but not on Linux.

The fix is one kernel parameter. No driver, no kernel build.

## Symptoms

- Video over HDMI works. Touch does nothing.
- Touch works on (some) Windows PCs with the same cable.
- `lsusb` shows the monitor's internal hub but no touch controller.
- `dmesg` shows the device behind the hub failing to enumerate:

```
usb 3-1.2: new full-speed USB device number 35 using xhci-hcd
usb 3-1.2: unable to read config index 0 descriptor/start: -32
usb 3-1.2: chopping to 0 config(s)
usb 3-1.2: can't read configurations, error -32
usb 3-1.2: device descriptor read/64, error -32
usb 3-1-port2: attempt power cycle
usb 3-1.2: Device not responding to setup address.
usb 3-1.2: device not accepting address 37, error -71
usb 3-1-port2: unable to enumerate USB device
```

Seen on Raspberry Pi 5, Raspberry Pi 4 (USB-A and USB-C/dwc2) and an Intel laptop
running Linux Mint (kernel 6.8).

## Hardware

| Part | ID |
|---|---|
| Panel (EDID) | `RTK CX156A`, 1920x1080 |
| Internal USB hub | `1a40:0101` Terminus Technology, self-powered |
| Touch controller, digitizer mode | `eeef:2828` "TSTP MTouch", serial `CMTP_1.0` |
| Touch controller, mouse mode | `0416:c169` (also seen as `0416:c168`) "TSTP MTouch" |

The touch controller sits on port 2 of the internal hub. It switches between the
two IDs by itself: it enumerates as `eeef:2828`, then re-enumerates as `0416:c169`.
The same controller is used in other UPERFECT models, see
[cx158-touch-warp](https://github.com/kashmeister/cx158-touch-warp).

## Fix

Add this to the end of the single line in `/boot/firmware/cmdline.txt`
(or to `GRUB_CMDLINE_LINUX` on a PC), then reboot:

```
usbcore.quirks=eeef:2828:rng,0416:c168:rng,0416:c169:rng,1a40:0101:o
```

To test without rebooting:

```sh
echo 'eeef:2828:rng,0416:c168:rng,0416:c169:rng,1a40:0101:o' | sudo tee /sys/module/usbcore/parameters/quirks
```

Then remove all power from the monitor for 20 seconds and reconnect it (see
[Power order](#power-order)). Once the controller has failed it stays stuck until
it loses power, so re-plugging only the data cable does not help.

Result: the controller enumerates and binds as a HID input device:

```
usb 1-1.2.2: New USB device found, idVendor=eeef, idProduct=2828
usb 1-1.2.2: New USB device found, idVendor=0416, idProduct=c169
input: TSTP MTouch as /devices/.../0003:0416:C169.0010/input/input26
hid-generic 0003:0416:C169.0010: input,hidraw2: USB HID v1.11 Mouse [TSTP MTouch]
```

### What each flag does

| Flag | Kernel quirk | Effect |
|---|---|---|
| `r` | `USB_QUIRK_WINDOWS_CONFIG_REQ_SIZE` | Ask for 255 bytes of the configuration descriptor first, like Windows, instead of 9 bytes |
| `n` | `USB_QUIRK_DELAY_CTRL_MSG` | Wait 200 ms after each control message |
| `g` | `USB_QUIRK_DELAY_INIT` | Wait 200 ms before reading the full configuration |
| `o` | `USB_QUIRK_HUB_SLOW_RESET` (on the hub) | Longer reset on the hub's downstream ports |

`r` alone was not enough. The controller answered only once the 200 ms delays
(`n`, `g`) were added. The `r` quirk needs a recent kernel; it is present in the
Raspberry Pi OS 6.18 kernels.

## Power order

The monitor tries to power up from the USB cable alone. If the Pi's USB port
powers it before its own USB-C PD supply does, the touch controller starts
under-powered and locks up. On a Pi 5 this also trips the USB over-current
protection on all ports (`usb usb3-port1: over-current change`).

Working order:

1. Connect the monitor's own PD power supply.
2. Wait about 15 seconds.
3. Connect the USB cable to the Pi.

## Monitor does not wake up after the Pi reboots

The monitor only looks for a signal when it receives power (or when a USB-C
host with DisplayPort is connected). If the Pi reboots while the monitor is on,
the monitor goes to sleep and does not come back, even though the Pi is sending
1920x1080@60.

Tried without success:

- `video=HDMI-A-1:1920x1080@60D` (force the output on) in `cmdline.txt`
- `hdmi_force_hotplug=1` in `config.txt`
- Turning the HDMI output off and on with `wlr-randr`
- Unplugging and re-plugging the HDMI cable or the USB cable
- Setting *Setup > Signal Source* to HDMI in the monitor menu
- Powering the Pi and the monitor at the same time

What works is powering the monitor after the Pi is already sending video.
To automate it you need something that switches the monitor's power after the
Pi has booted, such as a smart plug or a relay.

## How the cause was found

The Linux USB monitor showed the exchange. Load it and capture while the monitor
powers up:

```sh
sudo modprobe usbmon
sudo cat /sys/kernel/debug/usb/usbmon/3u > usbmon.txt   # 3 = USB bus number
```

The controller answered the device descriptor and then stopped answering at the
configuration descriptor request. A Windows PC with an AMD USB controller
enumerated it on the first try in digitizer mode (`eeef:2828`), which pointed to a
difference in how the host talks to it rather than to a broken monitor.

## Also useful on a Raspberry Pi 5

- Use the official 5V/5A (27W) supply. With a weaker supply the Pi limits all USB
  ports to 600 mA in total and ignores `usb_max_current_enable=1`.
- An under-powered Pi 5 corrupted the SD card and the bootloader EEPROM during a
  bootloader update in our tests (LED: 3 long, 1 short flashes = SPI EEPROM
  error). The official recovery image from
  [rpi-eeprom releases](https://github.com/raspberrypi/rpi-eeprom/releases)
  fixed it.

## Status

Tested on 2026-10-09 with Raspberry Pi OS (Trixie, kernel 6.18.50) on a
Raspberry Pi 4 Model B and a Raspberry Pi 5 Model B. Touch works on both.
Not yet tested with this fix: other Linux distributions, other UPERFECT models.

## License

CC0. Copy anything you need.
