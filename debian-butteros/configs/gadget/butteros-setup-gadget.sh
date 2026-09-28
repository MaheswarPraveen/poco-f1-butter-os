#!/bin/bash
# ButterOS USB ADB gadget — idempotent, survives systemd's own usb-gadget (RNDIS).
# NOTE: no `set -e` — a single failed echo must never kill adbd (that bricked USB).

# Mount configfs if needed
if [ ! -d /sys/kernel/config/usb_gadget ] && [ ! -d /config/usb_gadget ]; then
    mkdir -p /sys/kernel/config
    mount -t configfs none /sys/kernel/config 2>/dev/null || true
fi

if [ -d /config/usb_gadget ]; then
    CG_BASE="/config/usb_gadget"
else
    CG_BASE="/sys/kernel/config/usb_gadget"
fi

GADGET="$CG_BASE/g1"
mkdir -p "$GADGET/strings/0x409" 2>/dev/null || true

# Unbind whatever owns the UDC right now (e.g. systemd RNDIS), then take over
echo "none" > "$GADGET/UDC" 2>/dev/null || true
rm -f "$GADGET"/configs/b.1/f* 2>/dev/null || true
for f in "$GADGET"/functions/*; do
    [ -e "$f" ] || continue
    rmdir "$f" 2>/dev/null || true
done

echo 0x0200 > "$GADGET/bcdUSB" 2>/dev/null || true
echo 0x18d1 > "$GADGET/idVendor" 2>/dev/null || true
echo 0x4ee7 > "$GADGET/idProduct" 2>/dev/null || true

echo "3c10c267" > "$GADGET/strings/0x409/serialnumber" 2>/dev/null || true
echo "Xiaomi" > "$GADGET/strings/0x409/manufacturer" 2>/dev/null || true
echo "Poco F1 ButterOS" > "$GADGET/strings/0x409/product" 2>/dev/null || true

mkdir -p "$GADGET/configs/b.1/strings/0x409" 2>/dev/null || true
echo "adb" > "$GADGET/configs/b.1/strings/0x409/configuration" 2>/dev/null || true
echo 500 > "$GADGET/configs/b.1/MaxPower" 2>/dev/null || true

mkdir -p "$GADGET/functions/ffs.adb" 2>/dev/null || true
ln -sf "$GADGET/functions/ffs.adb" "$GADGET/configs/b.1/f1" 2>/dev/null || true

# Setup FunctionFS
mkdir -p /dev/usb-ffs/adb
umount /dev/usb-ffs/adb 2>/dev/null || true
mount -t functionfs adb /dev/usb-ffs/adb 2>/dev/null || true

# Start ADB Daemon
export LD_LIBRARY_PATH=/opt/android-adb/lib64
/opt/android-adb/linker64 /opt/android-adb/adbd &
ADBD_PID=$!

# Allow adbd to register endpoints with functionfs
sleep 1

# Bind UDC (retry: initramfs RNDIS gadget may still own it early in boot)
i=0
while [ $i -lt 6 ]; do
    UDC_DEV=$(ls /sys/class/udc 2>/dev/null | head -n 1)
    [ -z "$UDC_DEV" ] && UDC_DEV="a600000.usb"
    echo "none" > "$GADGET/UDC" 2>/dev/null || true
    echo "$UDC_DEV" > "$GADGET/UDC" 2>/dev/null || true
    BOUND=$(cat "$GADGET/UDC" 2>/dev/null || true)
    if [ "$BOUND" = "$UDC_DEV" ]; then
        echo "[ButterOS Gadget] USB ADB Gadget active on $UDC_DEV"
        break
    fi
    echo "[ButterOS Gadget] UDC bind pending (try $i)..." 2>/dev/null || true
    i=$((i + 1))
    sleep 5
done

wait $ADBD_PID
