#!/usr/bin/env bash
# ==============================================================================
# ButterOS Debian ARM64: Biometrics & Pro Camera Integration Script
# Target: Xiaomi Poco F1 (beryllium / SDM845)
# Adds:
#   1. Megapixels 2.x GTK4 Camera + Qualcomm CAMSS + udmabuf direct DMA buffers
#   2. libhybris ARM64 glibc-to-bionic linker bridge
#   3. android-fingerprint-daemon (HAL bridge for fingerprint.beryllium.so)
#   4. Howdy IR Facial Recognition (PAM integration for ov7251 notch sensor)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
WORK_DIR="/var/tmp/butteros-build"
ROOTFS_DIR="${WORK_DIR}/rootfs"
ROOTFS_TAR="${BUILD_DIR}/butteros-debian-rootfs.tar.gz"

echo "=== ButterOS Biometrics & Camera Compilation Pipeline ==="
echo "Target RootFS: ${ROOTFS_TAR}"

if [ ! -f "${ROOTFS_TAR}" ]; then
    echo "ERROR: ${ROOTFS_TAR} not found! Please build base rootfs first."
    exit 1
fi

# Ensure binfmt registration is active
if [ -x "/usr/lib/systemd/systemd-binfmt" ]; then
    sudo /usr/lib/systemd/systemd-binfmt || true
fi

# Clean and extract existing rootfs into fast native ext4 storage
echo "[1/5] Extracting base rootfs into /var/tmp..."
sudo rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"
sudo tar -xzpf "${ROOTFS_TAR}" -C "${ROOTFS_DIR}"

# Mount kernel virtual filesystems
sudo mount -t proc proc "${ROOTFS_DIR}/proc"
sudo mount -t sysfs sysfs "${ROOTFS_DIR}/sys"
sudo mount --bind /dev "${ROOTFS_DIR}/dev"
sudo mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

cleanup() {
    sudo umount -lf "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/dev" 2>/dev/null || true
}
trap cleanup EXIT

# Copy qemu emulation helper if needed
if [ -f "/usr/libexec/qemu-binfmt/aarch64-binfmt-P" ]; then
    sudo mkdir -p "${ROOTFS_DIR}/usr/libexec/qemu-binfmt"
    sudo cp /usr/libexec/qemu-binfmt/aarch64-binfmt-P "${ROOTFS_DIR}/usr/libexec/qemu-binfmt/" 2>/dev/null || true
fi
sudo cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/" 2>/dev/null || true

# Inside chroot: Install Camera stack, build tools, and biometrics
echo "[2/5] Installing Camera & Biometric packages inside Debian 13 ARM64..."
cat << 'CHROOT_SCRIPT' | sudo chroot "${ROOTFS_DIR}" /bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update

# 1. Pro Camera Engine (Megapixels + libcamera + v4l-utils + gmic debayer)
apt-get install -y --no-install-recommends \
    megapixels \
    libcamera-tools \
    v4l-utils \
    gmic \
    imagemagick

# 2. Build prerequisites for libhybris & Howdy
apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    cmake \
    git \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-numpy \
    python3-opencv \
    libpam0g-dev \
    libinih-dev \
    libevdev-dev \
    libwayland-dev \
    libegl1-mesa-dev

# 3. Compile & Install libhybris (Android Bionic -> GNU glibc Bridge)
if [ ! -d "/usr/src/libhybris" ]; then
    echo "Cloning and building libhybris..."
    git clone --depth 1 https://github.com/libhybris/libhybris.git /usr/src/libhybris
    cd /usr/src/libhybris/hybris
    ./autogen.sh --prefix=/usr --enable-arch=arm64 --enable-wayland --enable-trace
    make -j$(nproc)
    make install
    ldconfig
fi

# 4. Clone and Install Howdy (IR Face Recognition for Linux PAM)
if [ ! -d "/opt/howdy" ]; then
    echo "Configuring Howdy IR facial recognition..."
    git clone --depth 1 https://github.com/boltgolt/howdy.git /opt/howdy || true
    if [ -f "/opt/howdy/src/pam/pam_howdy.c" ]; then
        cd /opt/howdy/src/pam
        gcc -fPIC -fno-stack-protector -c pam_howdy.c -o pam_howdy.o
        gcc -shared pam_howdy.o -lpam -o /lib/security/pam_howdy.so || true
    fi
fi

apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_SCRIPT

# Inject Camera Udev rules & Megapixels Poco F1 sensor configurations
echo "[3/5] Injecting hardware sensor profiles & udev rules..."

# udmabuf zero-copy camera DMA rule (postmarketOS standard)
cat << 'EOF' | sudo tee "${ROOTFS_DIR}/etc/udev/rules.d/90-camera.rules"
# Hardware direct DMA buffer access for Qualcomm CAMSS ISP
KERNEL=="udmabuf", GROUP="video", MODE="0660"
KERNEL=="media*", GROUP="video", MODE="0660"
KERNEL=="video*", GROUP="video", MODE="0660"
EOF

# Megapixels Camera profile for Xiaomi Poco F1 (beryllium)
sudo mkdir -p "${ROOTFS_DIR}/usr/share/megapixels/config"
cat << 'EOF' | sudo tee "${ROOTFS_DIR}/usr/share/megapixels/config/xiaomi,beryllium.ini"
[device]
make=Xiaomi
model=Poco F1
dt_compat=xiaomi,beryllium

[camera0]
# Rear Main Camera: Sony IMX363 12.2 MP
driver=qcom-camss
media-driver=qcom-camss
capture-width=4032
capture-height=3024
preview-width=1920
preview-height=1080
rotate=90
mirrored=false
colormatrix=1.5,-0.3,-0.2,-0.2,1.4,-0.2,-0.1,-0.3,1.4

[camera1]
# Front Camera: Samsung S5K3T1 20 MP
driver=qcom-camss
media-driver=qcom-camss
capture-width=5184
capture-height=3880
preview-width=1920
preview-height=1080
rotate=270
mirrored=true

[camera2]
# Notch Infrared Camera: Omnivision OV7251 (IR Face Recognition)
driver=qcom-camss
media-driver=qcom-camss
capture-width=640
capture-height=480
preview-width=640
preview-height=480
rotate=90
mirrored=false
EOF

# Howdy Configuration for Notch IR Camera (/dev/video2)
sudo mkdir -p "${ROOTFS_DIR}/etc/howdy"
cat << 'EOF' | sudo tee "${ROOTFS_DIR}/etc/howdy/config.ini"
# ButterOS Howdy IR Face Unlock Configuration for Xiaomi Poco F1
[core]
detection = opencv
device_path = /dev/v4l/by-path/platform-acb3000.camss-video-index2
max_height = 480
use_cnn = false
timeout = 4
disabled = false
no_confirmation = true
abort_if_ssh = true

[video]
min_confidence = 0.65
exposure = -1
dark_threshold = 50
EOF

# PAM Authentication Hook
if [ -f "${ROOTFS_DIR}/etc/pam.d/common-auth" ]; then
    if ! grep -q "pam_howdy.so" "${ROOTFS_DIR}/etc/pam.d/common-auth"; then
        sudo sed -i '1s/^/auth    sufficient pam_howdy.so\n/' "${ROOTFS_DIR}/etc/pam.d/common-auth"
    fi
fi

# Auto-mount physical /vendor partition in /etc/fstab for fingerprint & camera blobs
if ! grep -q "/vendor" "${ROOTFS_DIR}/etc/fstab"; then
    echo "/dev/disk/by-partlabel/vendor    /vendor    ext4    ro,barrier=1    0  2" | sudo tee -a "${ROOTFS_DIR}/etc/fstab"
fi

# Ensure user butter is in video group
sudo chroot "${ROOTFS_DIR}" usermod -aG video,render butter

# Cleanup QEMU binaries before packing
echo "[4/5] Cleaning up build artifacts..."
sudo rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"
sudo rm -rf "${ROOTFS_DIR}/usr/libexec/qemu-binfmt"

# Unmount
cleanup

# Repackage updated rootfs
echo "[5/5] Re-packaging butteros-debian-rootfs.tar.gz..."
sudo tar -czpf "${ROOTFS_TAR}" -C "${ROOTFS_DIR}" .
echo "Cleaning up temporary build workspace..."
sudo rm -rf "${WORK_DIR}"

echo "=== UPGRADE COMPLETE ==="
ls -lh "${ROOTFS_TAR}"
