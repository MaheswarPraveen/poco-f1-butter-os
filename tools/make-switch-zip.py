#!/usr/bin/env python3
# ADD-ON dev tool: build an OrangeFox/TWRP-flashable zip that writes the ButterOS boot image to
# the boot partition and verifies it (the way back from Android, which isn't rooted).
#   python make-switch-zip.py butteros-boot.img switch-to-butteros.zip
import sys, zipfile

img, out = sys.argv[1], sys.argv[2]
update_binary = r'''#!/sbin/sh
# ButterOS: switch to ButterOS (writes boot image, verifies, reboots)
OUTFD=$2; ZIP=$3
ui_print() { echo "ui_print $1" > /proc/self/fd/$OUTFD; echo "ui_print" > /proc/self/fd/$OUTFD; }
ui_print "ButterOS: switching boot image..."
BOOT=/dev/block/bootdevice/by-name/boot
unzip -p "$ZIP" boot.img > /tmp/butteros-boot.img || { ui_print "unzip failed"; exit 1; }
SIZE=$(stat -c %s /tmp/butteros-boot.img)
WANT=$(md5sum /tmp/butteros-boot.img | cut -d' ' -f1)
dd if=/tmp/butteros-boot.img of=$BOOT bs=1048576 conv=fsync 2>/dev/null; sync
GOT=$(head -c $SIZE $BOOT | md5sum | cut -d' ' -f1)
if [ "$WANT" = "$GOT" ]; then
  ui_print "ButterOS boot image written and verified."
  ui_print "Tap 'Reboot System' to start ButterOS."
  exit 0
fi
ui_print "VERIFY FAILED - boot partition may be damaged. Flash butteros-boot.img manually."
exit 1
'''
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('META-INF/com/google/android/update-binary', update_binary.replace('\r', ''))
    z.writestr('META-INF/com/google/android/updater-script', '#MAGISK\n')
    z.write(img, 'boot.img')
print('built', out)
