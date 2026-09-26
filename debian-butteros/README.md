# ButterOS: Debian 13 (Trixie) ARM64 for Xiaomi Poco F1 (`beryllium`)

A native bare-metal mobile Linux operating system for the **Xiaomi Pocophone F1 (Qualcomm Snapdragon 845 / Adreno 630)**, powered by **Debian 13 (Trixie) arm64**, **Labwc (wlroots) Wayland kiosk compositor**, **Mesa 25 Freedreno/Turnip GPU acceleration**, and the custom ButterOS mobile shell.

---

## 1. System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│  BUTTEROS MOBILE SHELL                                                 │
│  - Dual Perimeter Rails (Left/Right continuous 40-app conveyer)        │
│  - 12-Spoke 360° GPU Matrix Rotary Quick Settings (120 FPS free-wheel) │
│  - Full A-Z App Drawer & Direct 1:1 Swipe-Down to Homepage             │
│  - 3D Rolodex Spatial Notification Deck                                │
├────────────────────────────────────────────────────────────────────────┤
│  WAYLAND COMPOSITOR & GRAPHICS                                         │
│  - Compositor: Labwc 0.8.3 (wlroots 0.18 layer-shell kiosk)            │
│  - GPU Acceleration: Mesa 25.0.x (Turnip Vulkan 1.3 + Freedreno GLES)  │
│  - Jitter Prevention: WLR_SCENE_DISABLE_DIRECT_SCANOUT=1               │
│  - Hardware Notch Margin: margin top="45" (90 physical px) in rc.xml   │
│  - Mobile Helpers: wvkbd (virtual keyboard) + lisgd (touch gestures)   │
├────────────────────────────────────────────────────────────────────────┤
│  MOBILE LINUX SERVICES (systemd)                                       │
│  - Audio: PipeWire 1.4.2 + WirePlumber 0.5.8 + ALSA UCM2 (beryllium)  │
│  - Audio Lock: alsa-restore.service masked to protect UCM state        │
│  - Cellular & Modem: ModemManager 1.22+ + QRTR Router + RMTFS          │
│  - Connectivity: NetworkManager + wpa_supplicant + bluez               │
│  - Hardware MAC: Synthesized Bluetooth/Wi-Fi MAC injector script       │
│  - Power Management: lc898217xc camera OIS suspend/sleep unbind hook   │
├────────────────────────────────────────────────────────────────────────┤
│  BASE OS                                                               │
│  - Distribution: Debian GNU/Linux 13 (Trixie / Testing) arm64          │
│  - Standard C Library: glibc 2.41 (pure 64-bit time_t)                 │
│  - Default User: butter (passwordless sudo enabled)                    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Generated Build Artifacts

The build pipeline has generated the following ready-to-deploy files in `debian-butteros/build/`:

* **`butteros-installer.zip` (451.95 MB)**:
  TWRP / OrangeFox recovery flashable zip. Includes automated `update-binary` installer for non-destructive loopback deployment.
* **`butteros-debian-rootfs.tar.gz` (452.0 MB)**:
  Complete Debian 13 ARM64 root filesystem archive containing the full driver stack, Labwc compositor, audio profiles, and ButterOS shell.

---

## 3. Non-Destructive Flashing Guide (Zero Android Data Loss)

> [!IMPORTANT]
> The ButterOS recovery installer installs into a dedicated **6GB ext4 loopback image** at `/data/butteros/rootfs.img`.
> It **does not wipe**, **does not format**, and **does not touch** your existing Android `/data`, photos, or apps!

### Step 1: Copy Installer to Device
When you have the phone booted into **TWRP** or **OrangeFox Recovery** and connected via USB:
```powershell
adb push build\butteros-installer.zip /sdcard/
```
*(Or transfer via USB OTG pendrive / micro-SD card).*

### Step 2: Flash via Recovery
1. In TWRP / OrangeFox, tap **Install**.
2. Select **`butteros-installer.zip`** from `/sdcard/`.
3. Swipe to Confirm Flash.
4. The installer will:
   - Verify device compatibility (`beryllium` / `POCO_F1`).
   - Create `/data/butteros/rootfs.img` non-destructively.
   - Format the container as ext4 and extract the Debian 13 rootfs.
   - Configure `/etc/fstab`.

---

## 4. Dual Boot & Kernel Loading

To boot into ButterOS without replacing your Android OS:
* Flash the mainline Linux 6.6+ kernel to the `recovery` partition (`boot.img` format with initramfs mounting `/data/butteros/rootfs.img`).
  - **Normal Power On**: Boots standard Android.
  - **Power + Volume Up**: Boots ButterOS Debian mobile Linux.
