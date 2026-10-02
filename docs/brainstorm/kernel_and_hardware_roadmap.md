# ButterOS Kernel, Hardware & Performance Roadmap

This document outlines the strategic hardware milestones, kernel evolution plan, and future feature implementations brainstormed for **ButterOS on the Xiaomi Poco F1 (`beryllium`)**.

---

## 🐧 1. Custom Mainline Kernel Evolution

### Current Kernel Baseline:
* Running `7.1.0-rc1-sdm845`.
* **Identified Regressions**:
  - FastRPC sensor communication regression causes the SLPI DSP to crash-loop (`err_qdi.c:456:EF:sensor_process`), necessitating `butteros-slpi-off.service`.
  - Charger driver input current limit clamped to 25mA over standard dev laptop USB links.
  - Race condition between in-kernel `pd-mapper` and userspace `protection-domain-mapper`.

### Target Custom Kernel Architecture:
* **Branch**: Mainline Linux 6.6 LTS or 6.12 LTS from the `sdm845-mainline` tree.
* **Kernel Defconfig Tweaks**:
  - Enable in-kernel `CONFIG_QCOM_PD_MAPPER=y` and disable conflicting userspace packages.
  - Revert problematic FastRPC patches to restore native accelerometer and gyroscope sensors on SLPI.
  - Patch PMIC charger driver to force a 500mA/900mA floor for SDP/CDP USB connections.
* **Deployment Safety Protocol**:
  - Always verify candidate kernels with `fastboot boot boot.img` over USB before flashing to the partition.

---

## 📷 2. Camera Subsystem (Sony IMX363)

### Hardware Specs:
* **Primary Sensor**: Sony IMX363 12.2 MP, 1.4µm pixels, f/1.9 aperture, Dual Pixel Phase Detection AF.
* **Secondary Sensor**: Samsung S5K5E8 5 MP depth sensor.
* **Front Sensor**: OmniVision OV20880 20 MP.

### Bring-up Strategy:
1. **Qualcomm CAMSS Driver**:
   - Ensure `qcom-camss` kernel module is loaded and probes the CSIPHY/CSID interfaces.
2. **Buffer Management**:
   - Configure `/dev/udmabuf` with `chmod 0660 /dev/udmabuf` and assign `video` group permissions.
3. **Userspace Integration**:
   - Utilize `libcamera` with the software ISP pipeline.
   - Bridge video stream into PipeWire using `pipewire-v4l2`.
   - Implement camera preview in ButterOS via HTML5 `<video>` / `getUserMedia()` or native `snapshot` / `gnome-camera`.

---

## 🍎 3. Sensory Physics & iOS-Level Fluidity

### ButterOS Mobile Shell Polish:
1. **Kinetic Inertia & Physics Rails**:
   - Refine the dual perimeter 40-app continuous conveyor with spring-damper physics (`F = -kx - cv`).
   - 120 FPS free-wheeling on the 360° rotary quick settings wheel.
   - Detent pause with subtle haptic vibration before opening the full application drawer.
2. **CDP Performance Profiling**:
   - Leverage Chromium's `--remote-debugging-port=9222` to trace frame rendering, GPU overdraw, and compositor rasterization via Chrome DevTools.
3. **Always-On-Top Global Status Bar**:
   - Transition status bar and battery indicators from in-page elements to a dedicated Wayland layer-shell overlay (`ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY`) that remains permanently visible above third-party GTK/QT applications.

---

## 🔄 4. Android (CloverOS) Dual-Boot Deep Integration

1. **Android-to-ButterOS 1-Tap Switching**:
   - Root Android CloverOS with Magisk.
   - Create an Android quick settings tile / widget that executes:
     `su -c "dd if=/data/butteros/boot-images/butteros-boot.img of=/dev/block/bootdevice/by-name/boot && reboot"`
   - Eliminates the need to enter OrangeFox Recovery just to switch back to Linux.
2. **Shared Storage Partitioning**:
   - Mount Android `/sdcard` (internal storage) inside ButterOS at `/media/android-storage` for seamless bi-directional file sharing (photos, music, downloads).
