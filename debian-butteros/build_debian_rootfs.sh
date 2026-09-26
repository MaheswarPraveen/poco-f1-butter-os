#!/usr/bin/env bash
# ==============================================================================
# ButterOS Debian ARM64 RootFS Builder for Xiaomi Poco F1 (SDM845 / Beryllium)
# Base: Debian 13 (Trixie) arm64
# Compositor: Labwc (wlroots) + Mesa Freedreno/Turnip (Adreno 630)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
WORK_DIR="/var/tmp/butteros-build"
ROOTFS_DIR="${WORK_DIR}/rootfs"
TARGET_ARCH="arm64"
DEBIAN_SUITE="trixie"
DEBIAN_MIRROR="http://deb.debian.org/debian"

echo "=== ButterOS Debian ARM64 Rootfs Builder ==="
echo "Target: Xiaomi Poco F1 (beryllium) - Qualcomm Snapdragon 845"
echo "Architecture: ${TARGET_ARCH}"
echo "Suite: ${DEBIAN_SUITE} (Debian 13 Testing - Modern Mobile Stack)"

# Ensure required host build packages are installed in WSL Ubuntu
echo "[1/7] Checking host dependencies..."
MISSING_PKGS=()
for pkg in debootstrap qemu-user-static binfmt-support tar gzip xz-utils git; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Installing missing build dependencies: ${MISSING_PKGS[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PKGS[@]}"
fi

# Ensure binfmt_misc has registered qemu-aarch64 in WSL2 kernel
if [ -x "/usr/lib/systemd/systemd-binfmt" ]; then
    /usr/lib/systemd/systemd-binfmt || true
fi

# Ensure debootstrap has the trixie script (symlink to sid if needed)
if [ ! -f "/usr/share/debootstrap/scripts/${DEBIAN_SUITE}" ]; then
    if [ -f "/usr/share/debootstrap/scripts/sid" ]; then
        sudo ln -s sid "/usr/share/debootstrap/scripts/${DEBIAN_SUITE}"
    fi
fi

# Clean previous build tree if requested
if [ -d "${ROOTFS_DIR}" ]; then
    echo "Existing rootfs found. Cleaning mount points..."
    sudo umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/sys" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    sudo umount -lf "${ROOTFS_DIR}/dev" 2>/dev/null || true
    sudo rm -rf "${ROOTFS_DIR}"
fi
mkdir -p "${WORK_DIR}"
mkdir -p "${BUILD_DIR}"

# Stage 1: debootstrap foreign architecture
echo "[2/7] Bootstrapping Debian ${DEBIAN_SUITE} (${TARGET_ARCH})..."
sudo debootstrap \
    --arch="${TARGET_ARCH}" \
    --foreign \
    --variant=minbase \
    --include=systemd,systemd-sysv,sudo,curl,wget,ca-certificates,locales \
    "${DEBIAN_SUITE}" \
    "${ROOTFS_DIR}" \
    "${DEBIAN_MIRROR}"

# Copy qemu-aarch64-static into rootfs
echo "[3/7] Setting up QEMU ARM64 user emulation..."
sudo cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/" 2>/dev/null || true
if [ -f "/usr/libexec/qemu-binfmt/aarch64-binfmt-P" ]; then
    sudo mkdir -p "${ROOTFS_DIR}/usr/libexec/qemu-binfmt"
    sudo cp /usr/libexec/qemu-binfmt/aarch64-binfmt-P "${ROOTFS_DIR}/usr/libexec/qemu-binfmt/" 2>/dev/null || true
fi

# Stage 2: Second stage debootstrap inside chroot
echo "[4/7] Completing second-stage debootstrap..."
sudo chroot "${ROOTFS_DIR}" /debootstrap/debootstrap --second-stage

# Mount kernel virtual filesystems
sudo mount -t proc proc "${ROOTFS_DIR}/proc"
sudo mount -t sysfs sysfs "${ROOTFS_DIR}/sys"
sudo mount --bind /dev "${ROOTFS_DIR}/dev"
sudo mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

trap 'sudo umount -lf "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/dev" 2>/dev/null || true' EXIT

# Configure Apt Repositories & Install Mobile Linux Packages
echo "[5/7] Installing ButterOS Wayland & Qualcomm SDM845 driver stack (Debian Trixie)..."
cat << 'EOF' | sudo tee "${ROOTFS_DIR}/etc/apt/sources.list"
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

cat << 'CHROOT_SCRIPT' | sudo chroot "${ROOTFS_DIR}" /bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Essential system utilities & networking
apt-get install -y --no-install-recommends \
    systemd-timesyncd \
    network-manager \
    wpasupplicant \
    modemmanager \
    qrtr-tools \
    rmtfs \
    libpam-systemd \
    dbus-user-session \
    htop \
    nano \
    python3 \
    pciutils \
    usbutils \
    evtest \
    bluez \
    brightnessctl

# ADD-ON: boot animation player + phone base layer (see configs/base/butteros-base-setup.sh)
apt-get install -y --no-install-recommends mpv alsa-utils swayidle qcom-phone-utils callaudiod \
    pipewire-pulse pipewire-alsa rtkit wlrctl rfkill upower || echo "WARNING: phone base packages failed"

# Modern Mesa 24+ natively in Trixie (Turnip Vulkan 1.3 + Freedreno OpenGL ES 3.2)
apt-get install -y --no-install-recommends \
    mesa-vulkan-drivers \
    libgl1-mesa-dri \
    libegl-mesa0 \
    libgbm1 \
    mesa-va-drivers

# Audio stack (PipeWire 1.2+ & WirePlumber 0.5+ with ALSA UCM)
apt-get install -y --no-install-recommends \
    pipewire \
    wireplumber \
    pipewire-audio-client-libraries \
    alsa-ucm-conf \
    alsa-utils

# Mask alsa-restore.service to prevent UCM mixer corruption on boot
systemctl mask alsa-restore.service

# Wayland Compositor (Labwc), On-Screen Keyboard (wvkbd), Gestures (lisgd), and Browser Kiosk Host
apt-get install -y --no-install-recommends \
    labwc \
    chromium \
    fonts-inter \
    fonts-noto-color-emoji \
    libinput-bin \
    wvkbd \
    lisgd \
    megapixels \
    feedbackd \
    callaudiod || true

# Create default ButterOS user
if ! id -u butter >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,video,render,input,audio,dialout butter
    echo "butter:butter" | chpasswd
    echo "root:butter" | chpasswd
fi

# Enable passwordless sudo for user butter
echo "butter ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/butter
chmod 0440 /etc/sudoers.d/butter

# Set hostname
echo "butteros-poco" > /etc/hostname
cat << 'HOSTS' > /etc/hosts
127.0.0.1   localhost
127.0.1.1   butteros-poco
HOSTS

# Set locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_SCRIPT

# Install ButterOS Shell Assets & Service Configurations
echo "[6/7] Installing ButterOS shell assets and system configurations..."
sudo mkdir -p "${ROOTFS_DIR}/usr/share/butteros"
sudo mkdir -p "${ROOTFS_DIR}/usr/local/bin"
sudo mkdir -p "${ROOTFS_DIR}/etc/systemd/system"
sudo mkdir -p "${ROOTFS_DIR}/etc/udev/rules.d"
sudo mkdir -p "${ROOTFS_DIR}/home/butter/.config/labwc"
sudo mkdir -p "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d"
sudo mkdir -p "${ROOTFS_DIR}/usr/lib/systemd/system-sleep"

# Copy shell.html (ADD-ON fix: was copying stale android-launcher/assets copy; live source is shell/shell.html)
sudo cp "${SCRIPT_DIR}/shell/shell.html" "${ROOTFS_DIR}/usr/share/butteros/shell.html"
sudo chmod 0644 "${ROOTFS_DIR}/usr/share/butteros/shell.html"

# Copy configurations
sudo cp "${SCRIPT_DIR}/configs/systemd/butteros-shell.service" "${ROOTFS_DIR}/etc/systemd/system/"
sudo cp "${SCRIPT_DIR}/configs/wayland/butteros-session.sh" "${ROOTFS_DIR}/usr/local/bin/butteros-session"
sudo chmod +x "${ROOTFS_DIR}/usr/local/bin/butteros-session"

# ADD-ON fix: install the bridge the session execs (was never installed -> app launches silently died)
sudo cp "${SCRIPT_DIR}/configs/butteros-bridge.py" "${ROOTFS_DIR}/usr/local/bin/butteros-bridge.py"
sudo chmod +x "${ROOTFS_DIR}/usr/local/bin/butteros-bridge.py"

sudo cp "${SCRIPT_DIR}/configs/wayland/rc.xml" "${ROOTFS_DIR}/home/butter/.config/labwc/rc.xml"
sudo cp "${SCRIPT_DIR}/configs/systemd/wcn3990-mac-setup.sh" "${ROOTFS_DIR}/usr/local/bin/wcn3990-mac-setup"
sudo chmod +x "${ROOTFS_DIR}/usr/local/bin/wcn3990-mac-setup"

sudo cp "${SCRIPT_DIR}/configs/systemd/51-qcom-sdm845.conf" "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d/"
sudo cp "${SCRIPT_DIR}/configs/systemd/10-camera-motor.sh" "${ROOTFS_DIR}/usr/lib/systemd/system-sleep/"
sudo chmod +x "${ROOTFS_DIR}/usr/lib/systemd/system-sleep/10-camera-motor.sh"

sudo cp "${SCRIPT_DIR}/configs/udev/99-poco-f1.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"
# ADD-ON: touchscreen classification rules (were built but never installed)
sudo cp "${SCRIPT_DIR}/configs/udev/99-pocof1-touchscreen.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"
# ADD-ON: fallback compositor config location (push script deploys both; fresh builds had only home)
sudo mkdir -p "${ROOTFS_DIR}/etc/xdg/labwc"
sudo cp "${SCRIPT_DIR}/configs/wayland/rc.xml" "${ROOTFS_DIR}/etc/xdg/labwc/rc.xml"
# ADD-ON: software RTC offset (SDM845 RTC is read-only; without this the clock resets to 1970)
sudo install -m 0755 "${SCRIPT_DIR}/configs/time/butteros-rtc-offset.sh" "${ROOTFS_DIR}/usr/local/bin/butteros-rtc-offset"
sudo install -m 0644 -t "${ROOTFS_DIR}/etc/systemd/system/" \
    "${SCRIPT_DIR}/configs/time/butteros-rtc-offset.service" \
    "${SCRIPT_DIR}/configs/time/butteros-rtc-offset-save.service" \
    "${SCRIPT_DIR}/configs/time/butteros-rtc-offset-save.timer" \
    "${SCRIPT_DIR}/configs/time/butteros-rtc-offset-save.path"
sudo install -m 0644 "${SCRIPT_DIR}/configs/time/90-butteros-rtc.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"
# ADD-ON: boot animation (video + sound via mpv on DRM, before the shell starts)
sudo install -m 0644 "${SCRIPT_DIR}/configs/bootanim/bootanimation.mp4" "${ROOTFS_DIR}/usr/share/butteros/bootanimation.mp4"
sudo install -m 0755 "${SCRIPT_DIR}/configs/bootanim/butteros-bootanim.sh" "${ROOTFS_DIR}/usr/local/bin/butteros-bootanim"
sudo install -m 0644 "${SCRIPT_DIR}/configs/bootanim/butteros-bootanim.service" "${ROOTFS_DIR}/etc/systemd/system/"
# ADD-ON: stop the SLPI fastrpc probe loop (burned a full core + heat)
sudo mkdir -p "${ROOTFS_DIR}/etc/modprobe.d"
sudo install -m 0644 "${SCRIPT_DIR}/configs/modprobe/butteros-no-fastrpc.conf" "${ROOTFS_DIR}/etc/modprobe.d/"

# Fetch device-specific ALSA UCM2 configurations for Poco F1 (Xiaomi/beryllium)
if [ ! -d "${ROOTFS_DIR}/usr/share/alsa/ucm2/Xiaomi/beryllium" ]; then
    echo "Cloning Xiaomi Poco F1 ALSA UCM configurations..."
    rm -rf "${WORK_DIR}/alsa-ucm-temp"
    git clone --depth 1 https://gitlab.com/sdm845-mainline/alsa-ucm-conf.git "${WORK_DIR}/alsa-ucm-temp" 2>/dev/null || true
    if [ -d "${WORK_DIR}/alsa-ucm-temp/ucm2/Xiaomi/beryllium" ]; then
        sudo mkdir -p "${ROOTFS_DIR}/usr/share/alsa/ucm2/Xiaomi"
        sudo cp -r "${WORK_DIR}/alsa-ucm-temp/ucm2/Xiaomi/beryllium" "${ROOTFS_DIR}/usr/share/alsa/ucm2/Xiaomi/"
        if [ -d "${WORK_DIR}/alsa-ucm-temp/ucm2/conf.d" ]; then
            sudo mkdir -p "${ROOTFS_DIR}/usr/share/alsa/ucm2/conf.d"
            sudo cp -r "${WORK_DIR}/alsa-ucm-temp/ucm2/conf.d"/* "${ROOTFS_DIR}/usr/share/alsa/ucm2/conf.d/" 2>/dev/null || true
        fi
        echo "ALSA UCM profiles for Poco F1 (beryllium) installed successfully."
    fi
    rm -rf "${WORK_DIR}/alsa-ucm-temp"
fi

# ADD-ON: hardware payload - kernel modules + firmware matching butteros-boot.img's kernel,
# Qualcomm helper .debs and the first-boot setup service. Produced by hw/fetch_hw_payload.sh.
# Without it Wi-Fi, Bluetooth, audio and modem drivers have nothing to load from.
HW_PAYLOAD="${BUILD_DIR}/hw-payload"
if [ -d "${HW_PAYLOAD}/usr/lib/modules" ]; then
    sudo cp -a "${HW_PAYLOAD}/." "${ROOTFS_DIR}/"
    echo "Hardware payload installed ($(ls "${HW_PAYLOAD}/usr/lib/modules"))."
else
    echo "WARNING: ${HW_PAYLOAD} not found - Wi-Fi/BT/audio/modem will NOT work."
    echo "         Run 'bash hw/fetch_hw_payload.sh' first, then rebuild."
fi

# Fix home ownership for butter user
sudo chroot "${ROOTFS_DIR}" chown -R butter:butter /home/butter

# Enable ButterOS Systemd Services
cat << 'CHROOT_SERVICES' | sudo chroot "${ROOTFS_DIR}" /bin/bash
systemctl enable NetworkManager.service
systemctl enable ModemManager.service
systemctl enable butteros-shell.service
# ADD-ON: first-boot hardware setup (installs Qualcomm helpers, enables rmtfs/tqftpserv/pd-mapper)
if [ -f /etc/systemd/system/butteros-hwsetup.service ]; then systemctl enable butteros-hwsetup.service; fi
# ADD-ON: RTC offset saving (restore is started by the udev rule, no enable needed)
systemctl enable butteros-rtc-offset-save.timer butteros-rtc-offset-save.path
# ADD-ON: boot animation (needs mpv + alsa-utils from the package list)
if command -v mpv >/dev/null; then systemctl enable butteros-bootanim.service; fi
CHROOT_SERVICES

# Remove qemu binary before final archive creation
sudo rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"
sudo rm -rf "${ROOTFS_DIR}/usr/libexec/qemu-binfmt"

# Unmount filesystems
sudo umount -lf "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/dev" 2>/dev/null || true

# Stage 3: Packaging into RootFS Tarball
echo "[7/7] Generating butteros-debian-rootfs.tar.gz..."
OUTPUT_TAR="${BUILD_DIR}/butteros-debian-rootfs.tar.gz"
sudo tar -czpf "${OUTPUT_TAR}" -C "${ROOTFS_DIR}" .

echo "=== BUILD COMPLETE! ==="
echo "RootFS Tarball: ${OUTPUT_TAR}"
ls -lh "${OUTPUT_TAR}"
echo "Cleaning up temporary build tree in /var/tmp..."
sudo rm -rf "${WORK_DIR}"
