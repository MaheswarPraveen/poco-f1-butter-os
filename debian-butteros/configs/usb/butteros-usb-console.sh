#!/bin/bash
# ADD-ON: ButterOS USB serial console (CDC-ACM gadget -> /dev/ttyGS0).
# Windows shows it as "USB Serial Device (COMx)"; serial-getty@ttyGS0 gives a shell on it.
# Idempotent. Takes the USB port over from any other gadget (e.g. the initramfs RNDIS one).
# Do NOT enable together with butteros-gadget.service (adbd) - only one gadget can own the port.
# NOTE: no `set -e` - a failed write must not leave the port dead.

CFG=/sys/kernel/config
G="$CFG/usb_gadget/butteros"

modprobe libcomposite 2>/dev/null
modprobe usb_f_acm 2>/dev/null
grep -q " $CFG " /proc/mounts || mount -t configfs none "$CFG" 2>/dev/null

UDC_DEV=""
for i in $(seq 1 10); do
    UDC_DEV="$(ls /sys/class/udc 2>/dev/null | head -n 1)"
    [ -n "$UDC_DEV" ] && break
    sleep 1
done
[ -n "$UDC_DEV" ] || { echo "[ButterOS USB] no USB device controller found"; exit 1; }

# release the controller from any other gadget
for u in "$CFG"/usb_gadget/*/UDC; do
    [ "$u" = "$G/UDC" ] && continue
    [ -n "$(cat "$u" 2>/dev/null)" ] && echo "" > "$u" 2>/dev/null && echo "[ButterOS USB] released $u"
done

if [ ! -d "$G/functions/acm.GS0" ]; then
    mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409"
    echo 0x1d6b > "$G/idVendor"          # Linux Foundation
    echo 0x0104 > "$G/idProduct"         # Multifunction Composite Gadget
    echo 0x0100 > "$G/bcdDevice"
    echo 0x0200 > "$G/bcdUSB"
    echo 0xEF   > "$G/bDeviceClass"      # IAD composite: Windows binds usbser.sys automatically
    echo 0x02   > "$G/bDeviceSubClass"
    echo 0x01   > "$G/bDeviceProtocol"
    echo "butteros-poco" > "$G/strings/0x409/serialnumber"
    echo "ButterOS"      > "$G/strings/0x409/manufacturer"
    echo "ButterOS Poco F1 Console" > "$G/strings/0x409/product"
    echo "Serial console" > "$G/configs/c.1/strings/0x409/configuration"
    echo 250 > "$G/configs/c.1/MaxPower"
    mkdir -p "$G/functions/acm.GS0"
    ln -sf "$G/functions/acm.GS0" "$G/configs/c.1/"
fi

echo "" > "$G/UDC" 2>/dev/null
for i in 1 2 3 4 5; do
    echo "$UDC_DEV" > "$G/UDC" 2>/dev/null
    [ "$(cat "$G/UDC" 2>/dev/null)" = "$UDC_DEV" ] && { echo "[ButterOS USB] serial console on $UDC_DEV"; exit 0; }
    sleep 2
done
echo "[ButterOS USB] could not bind $UDC_DEV"
exit 1
