# ButterOS Mobile Linux Project Handoff & Technical Architecture

**Target Hardware**: Xiaomi Poco F1 (`beryllium`, Qualcomm Snapdragon 845 / Adreno 630)  
**Host Workspace (PC)**: `C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\`  
**Target Rootfs on Device**: `/data/butteros/rootfs.img` (8.0 GB ext4 loop container on Android `/data`)  
**Base Distribution**: Debian 13 (Trixie) ARM64  
**Compositor**: Labwc (Wayland / wlroots)  
**Display Kiosk Shell**: Chromium Ozone Wayland (`/usr/share/butteros/shell.html`)

---

## 1. Directory Structure & Key Files

### Host Workspace
`C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\`
```text
poco-f1-butter-os/
├── debian-butteros/
│   ├── shell/
│   │   └── shell.html                  # Core ButterOS mobile kiosk shell (HTML5/CSS3/Vanilla JS)
│   ├── configs/
│   │   ├── wayland/
│   │   │   ├── butteros-session.sh     # Compositor startup script & Chromium kiosk launcher
│   │   │   └── rc.xml                  # Labwc configuration (DSI-1 output mapping & touch config)
│   │   ├── udev/
│   │   │   └── 99-pocof1-touchscreen.rules  # Udev rules for FocalTech/Synaptics multi-touch
│   │   └── gadget/
│   │       ├── butteros-setup-gadget.sh     # ConfigFS USB Gadget initialization script
│   │       └── butteros-gadget.service      # Systemd service for USB Gadget & adbd
│   └── systemd/
│       └── butteros-shell.service      # Main systemd kiosk service launching Labwc on tty1
```

### On-Device Mount & Container Paths
When mounted inside OrangeFox Recovery:
* **Loop mount target**: `/mnt/butteros` (`mount -t ext4 -o loop /data/butteros/rootfs.img /mnt/butteros`)
* **Shell HTML**: `/mnt/butteros/usr/share/butteros/shell.html`
* **Session Script**: `/mnt/butteros/usr/local/bin/butteros-session`
* **Labwc Config**: `/mnt/butteros/home/butter/.config/labwc/rc.xml`
* **USB Gadget Script**: `/mnt/butteros/usr/local/bin/butteros-setup-gadget.sh`
* **USB Gadget Unit**: `/mnt/butteros/etc/systemd/system/butteros-gadget.service`
* **Touchscreen Rule**: `/mnt/butteros/etc/udev/rules.d/99-pocof1-touchscreen.rules`
* **Bionic ADB Stack**: `/mnt/butteros/opt/android-adb/` (contains `linker64`, `adbd`, and Android `.so` libraries)

---

## 2. What Has Been Completed & Verified

1. **Non-Destructive Dual-Boot Architecture**:
   - Android userdata partition (`sda21`) remains untouched.
   - ButterOS operates entirely within `/data/butteros/rootfs.img`.
   - Booted via standard Android `boot.img` initramfs loop-mounting `/data/butteros/rootfs.img`.

2. **Display & GPU Acceleration**:
   - DRM/KMS scanout on `/dev/dri/card0` via Tianma `nt36672a` FHD panel.
   - Mesa Freedreno/Turnip drivers active with EGL/GLES2 hardware compositing.
   - Chromium runs with `--ozone-platform=wayland --enable-features=UseOzonePlatform --use-gl=egl`.

3. **Touchscreen Driver & Compositor Translation**:
   - Labwc `rc.xml` configured with `<mapToOutput>DSI-1</mapToOutput>` and `<mouseEmulation>no</mouseEmulation>`.
   - Chromium configured with coarse touch pointer flags:
     `--blink-settings=primaryPointerType=2,availablePointerTypes=2,primaryHoverType=1,availableHoverTypes=1`
   - Fixed the earlier JavaScript parser halting bug on line 3013 of `shell.html`. The JS engine now runs with 0 syntax errors.

4. **Handheld Rails**:
   - Left and right 64px flank rails docked at `left: 0` and `right: 0` by default.
   - Vertical conveyor scrolling functions across all 40 applications.
   - Tap-to-launch registered with scale haptic animation.

5. **USB Gadget Mode**:
   - Android bionic `adbd` and dynamic libraries copied to `/opt/android-adb/`.
   - Verified that `adbd` executes under Debian ARM64 (`Android Debug Bridge Daemon v1.0.41`).
   - Device exposes `USB\VID_18D1&PID_4EE7` (UsbNcm Host Device).

---

## 3. Open Issues & Direct Solutions

### Issue A: Inward Swipe on Rails Not Opening App Drawer
* **Root Cause**: In `shell.html`, inside `pointermove`, dragging on `rail-left` and `rail-right` only modifies `loopScrollOffset` via `currentDragY`. Horizontal delta (`currentDragX`) is not checking for inward threshold.
* **Fix**: In `pointermove` for rail targets:
  ```javascript
  // Swiping inward toward center opens App Drawer:
  if (activeTarget === 'rail-left' && currentDragX > 28 && Math.abs(currentDragX) > Math.abs(currentDragY) * 1.2) {
    openDrawer();
    isDragging = false;
    activeTarget = null;
    return;
  }
  if (activeTarget === 'rail-right' && currentDragX < -28 && Math.abs(currentDragX) > Math.abs(currentDragY) * 1.2) {
    openDrawer();
    isDragging = false;
    activeTarget = null;
    return;
  }
  ```

### Issue B: Clock Displays 1:48 (UTC) Instead of Local Time (03:57 IST)
* **Root Cause**: Mainline Linux kernel hardware clock on SDM845 boots in uncalibrated UTC, and browser `new Date()` defaults to UTC when timezone files are desynced.
* **Fix**: In `shell.html`, replace `new Date()` inside `updateClock()` with:
  ```javascript
  const now = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
  ```

### Issue C: ADB Over USB Gadget Not Binding in Windows
* **Root Cause**: Currently, the gadget binds as pure UsbNcm (`MI_00`). Windows attaches the NCM network driver, but ADB client expects the FunctionFS ADB interface descriptor (`Class 0xFF, SubClass 0x42, Protocol 0x01`).
* **Fix**: In `butteros-setup-gadget.sh`, write a composite multi-function gadget with both FunctionFS ADB and NCM:
  ```bash
  ln -s "$GADGET/functions/ffs.adb" "$GADGET/configs/b.1/f1"
  ln -s "$GADGET/functions/ncm.0"   "$GADGET/configs/b.1/f2"
  ```
  Ensure FunctionFS `/dev/usb-ffs/adb` is mounted before `adbd` launches, then write `a600000.dwc3` to `$GADGET/UDC`.

---

## 4. Standard Operational Commands

### Accessing Rootfs from OrangeFox Recovery
```bash
# Verify connection
adb devices

# Mount rootfs container
adb shell "mkdir -p /mnt/butteros && mount -t ext4 -o loop /data/butteros/rootfs.img /mnt/butteros"

# Push shell updates
adb push "C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\debian-butteros\shell\shell.html" /mnt/butteros/usr/share/butteros/shell.html

# Sync and unmount cleanly
adb shell "sync && umount /mnt/butteros"

# Reboot into ButterOS
adb reboot
```
