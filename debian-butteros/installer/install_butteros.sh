#!/sbin/sh
# ==============================================================================
# ButterOS Non-Destructive Recovery Installer for Xiaomi Poco F1 (beryllium)
# Safe, non-wiping installation via TWRP / OrangeFox Recovery
# ==============================================================================
set -e

OUTFD=$2
ui_print() {
    if [ -n "$OUTFD" ]; then
        echo "ui_print $1" > /proc/self/fd/$OUTFD
        echo "ui_print" > /proc/self/fd/$OUTFD
    else
        echo "$1"
    fi
}

ui_print "=========================================="
ui_print "       ButterOS: Debian for Poco F1       "
ui_print "      SDM845 • Adreno 630 • Wayland       "
ui_print "=========================================="

ui_print "[1/4] Checking hardware compatibility..."
DEVICE=$(getprop ro.product.device || getprop ro.build.product)
if [ "$DEVICE" != "beryllium" ] && [ "$DEVICE" != "POCO_F1" ]; then
    ui_print "WARNING: Device reports '$DEVICE' (expected beryllium)."
    ui_print "Continuing install for SDM845 platform..."
fi

# Target installation: /data/butteros loopback image to preserve Android data
INSTALL_DIR="/data/butteros"
IMAGE_FILE="${INSTALL_DIR}/rootfs.img"
IMAGE_SIZE_GB=6
MOUNT_POINT="/mnt/butteros_root"

ui_print "[2/4] Setting up non-destructive storage space..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${MOUNT_POINT}"

if [ ! -f "${IMAGE_FILE}" ]; then
    ui_print "Creating dedicated ${IMAGE_SIZE_GB}GB Linux image (${IMAGE_FILE})..."
    dd if=/dev/zero of="${IMAGE_FILE}" bs=1M count=$((IMAGE_SIZE_GB * 1024))
    ui_print "Formatting ext4 filesystem..."
    mke2fs -t ext4 -F "${IMAGE_FILE}"
else
    ui_print "Existing ButterOS rootfs.img found. Updating..."
fi

ui_print "[3/4] Mounting rootfs container..."
mount -t ext4 -o loop "${IMAGE_FILE}" "${MOUNT_POINT}"

ui_print "[4/4] Extracting ButterOS Debian ARM64 rootfs..."
tar -xzpf /tmp/butteros-debian-rootfs.tar.gz -C "${MOUNT_POINT}"

# Configure fstab inside rootfs
cat << 'EOF' > "${MOUNT_POINT}/etc/fstab"
# /etc/fstab: ButterOS Poco F1
/dev/root        /               ext4    errors=remount-ro 0       1
tmpfs            /tmp            tmpfs   defaults          0       0
EOF

sync
umount "${MOUNT_POINT}"
ui_print "=========================================="
ui_print "   ButterOS Debian Installed Successfully!"
ui_print "   Android & Personal Data Left Untouched."
ui_print "=========================================="
exit 0
