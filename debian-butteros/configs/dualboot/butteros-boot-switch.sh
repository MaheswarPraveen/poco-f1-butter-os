#!/bin/sh
# ==============================================================================
# ADD-ON: dual boot (ButterOS <-> Android / Clover OS).  butteros-boot-switch android|status
# The Poco F1 bootloader always boots the single "boot" partition, so switching OS = writing
# that OS's boot image there. Images (in /usr/share/butteros/boot-images):
#   android-boot.img  - stock Clover OS boot image (user's backup)
#   butteros-boot.img - ButterOS boot image (used to restore if a write fails)
# Returning from Android (not rooted): reboot to recovery -> OrangeFox -> Install ->
#   /data/butteros/switch-to-butteros.zip
# Every write is verified before rebooting; on mismatch the ButterOS image is put back.
# ==============================================================================
set -u
BOOT=/dev/disk/by-partlabel/boot
# Inside ButterOS the data partition isn't mounted on its own (rootfs.img is loop-mounted from
# it before switch_root), so the images the switch needs are kept inside the rootfs:
DIR=/usr/share/butteros/boot-images

write_verify() {   # $1 = image
    size=$(stat -c %s "$1") || return 1
    want=$(md5sum < "$1" | cut -c1-32)
    dd if="$1" of="$BOOT" bs=1M conv=fsync status=none || return 1
    sync
    got=$(head -c "$size" "$BOOT" | md5sum | cut -c1-32)
    [ "$want" = "$got" ]
}

case "${1:-status}" in
    android)
        img="$DIR/android-boot.img"
        [ -f "$img" ] || { echo "NO_ANDROID_IMAGE ($img)"; exit 1; }
        if write_verify "$img"; then
            echo "SWITCHED_TO_ANDROID - rebooting"
            sleep 1; systemctl reboot
        else
            echo "WRITE_FAILED - restoring ButterOS boot image"
            write_verify "$DIR/butteros-boot.img" && echo "RESTORED" || echo "RESTORE_FAILED - use OrangeFox"
            exit 1
        fi ;;
    status)
        for f in android-boot.img butteros-boot.img; do
            [ -f "$DIR/$f" ] && echo "ok  $f" || echo "missing  $f"
        done ;;
esac
