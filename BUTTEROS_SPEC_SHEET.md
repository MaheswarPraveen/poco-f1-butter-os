# ButterOS: Technical Specification Sheet & Implementation Blueprint
**Target Device**: Xiaomi Poco F1 (`beryllium`)  
**Architecture**: ARM64 (Qualcomm Snapdragon 845 / SDM845)  
**Distribution Model**: Minimalist Mobile Linux (Alpine / musl / OpenRC / Wayland)

---

## 1. Hardware Specification & Verified Device Tree Mapping

| Subsystem | Hardware Component | Linux Driver / Subsystem | Device Tree Node (`sdm845-xiaomi-beryllium.dts`) |
| :--- | :--- | :--- | :--- |
| **SoC** | Qualcomm SDM845 (10nm LPP) | Mainline ARM64 Kernel 6.6+ | `/soc` |
| **CPU Cluster** | 4x Kryo 385 Gold (Cortex-A75 @ 2.8 GHz)<br>4x Kryo 385 Silver (Cortex-A55 @ 1.77 GHz) | `cpufreq-qcom-hw`, Energy Aware Scheduling (EAS) | `/cpus`, `/soc/cpufreq@17d43000` |
| **GPU** | Qualcomm Adreno 630 | DRM/KMS `msm_drm`, Mesa Freedreno (Gallium) / Turnip (Vulkan) | `/soc/gpu@5000000` (`qcom,adreno-630.2`) |
| **Display Panel** | 6.18" IPS LCD (1080×2246 @ 60Hz, 18.7:9)<br>Tianma `nt36672a` / EBBG `ft8719` | DRM DSI Panel Driver | `/soc/dsi@ae94000/panel@0` |
| **Touchscreen** | FocalTech FT5446 / Synaptics | `i2c-qcom-geni`, `focaltech_ts` input driver | `/soc/i2c@a88000/touchscreen@38` (`/dev/input/eventX`) |
| **Modem (LTE)** | Snapdragon X20 LTE | Qualcomm IPC Router, QRTR, `qcom-qmi-wwan` | `/soc/remoteproc@4080000` (`modem-pil`) |
| **Audio DSP** | Hexagon 685 (QDSP6 v65) | `qcom,q6dsp`, FastRPC, ALSA UCM | `/soc/remoteproc@62400000` (`adsp-pil`) |
| **Power Management** | PM8998 + PMI8998 + SMB1355 | `qcom,spmi-pmic`, Linux `power_supply` | `/soc/spmi@c440000` |
| **Haptic Motor** | Linear Resonant Actuator (LRA) | `qcom,pm8998-vib`, `feedbackd` / sysfs | `/sys/class/leds/vibrator` |
| **Storage** | 64GB/128GB/256GB UFS 2.1 | `ufshcd-qcom`, ext4 / f2fs | `/soc/ufshc@1d84000` |

---

## 2. ButterOS Software Stack

```
┌────────────────────────────────────────────────────────────────────────┐
│  USER SPACE: BUTTEROS SHELL                                            │
│  - Dual Docked Edge Rails (76px width, retractable to screen bezels)   │
│  - Single Continuous Perimeter Conveyor Belt Loop (40 Apps)           │
│  - Inward Pinch/Swipe Morphing: Rails merge into centered 4x10 Drawer  │
│  - Dual Corner Radial Quick-Settings Arcs (3-Ring Polar Spoke System)  │
│  - Dedicated Full-Bleed Drop-Down Notification Center (Zero Scrollbars)│
├────────────────────────────────────────────────────────────────────────┤
│  WINDOWING & WAYLAND LAYER                                             │
│  - Compositor: Wayland Micro-Compositor (wlroots / cage / labwc)        │
│  - Protocols: wlr-layer-shell-unstable-v1, xdg-shell, linux-dmabuf-v1  │
│  - Graphics Engine: Mesa 24+ via DRM/KMS Atomic Scanout (/dev/dri/card0)│
├────────────────────────────────────────────────────────────────────────┤
│  SYSTEM MIDDLEWARE & MOBILE DAEMONS (D-Bus)                            │
│  - Telephony / Data: ModemManager + libqmi + QRTR Router               │
│  - Audio: PipeWire + WirePlumber (ALSA UCM Qualcomm QDSP6 profiles)   │
│  - Network: iwd (Intel Wireless Daemon)                                │
│  - Power: UPower (Direct sysfs fuel gauge)                             │
│  - Haptics: feedbackd (Poco F1 LRA tactile driver profiles)            │
├────────────────────────────────────────────────────────────────────────┤
│  BASE OPERATING SYSTEM & INIT                                          │
│  - Distribution Base: Alpine Linux (Edge / v3.20+)                     │
│  - C Standard Library: musl libc                                       │
│  - Init System: OpenRC                                                 │
│  - Device Node Daemon: mdevd / eudev                                   │
├────────────────────────────────────────────────────────────────────────┤
│  KERNEL & BOOTLOADER                                                   │
│  - Kernel: Mainline Linux 6.6+ LTS (SDM845 target)                     │
│  - Bootloader Interface: ABL (Little Kernel) via Android boot.img      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Shell Component Architecture & Interaction Engine

### 3.1. Dual Edge Rails & Perimeter Conveyor
- **Structure**: Two persistent side rails docked at the left and right viewports (`width: 76px`).
- **Perimeter Travel (Single Continuous Belt Loop)**:
  - 40 application launchers distributed symmetrically (Apps 1–20 on left rail, Apps 21–40 on right rail).
  - Dragging down on the left rail scrolls apps upward; dragging down on the right rail reverses direction, behaving as a single continuous mechanical belt traveling around the perimeter.
- **Retraction & Summon**:
  - Horizontal swipe outward tucks the rails off-screen into the bezels.
  - Inward swipe from the bezel edge summons them back into docked view.
  - Tapping empty middle space clears overlays and returns to the clean home screen.

### 3.2. Rail-to-Drawer Morphing & Direct Swipe-Down to Homepage
- **Transition**: Swiping inward horizontally across either docked rail initiates continuous physical morphing:
  - The left and right rail containers slide toward the center of the display.
  - The two vertical strips merge into a centered 4×10 full app drawer.
- **Direct Swipe-Down to Homepage (Mobile Shell Standard)**:
  - When the full App Drawer is open and the list is at the top (`drawerScrollOffset >= 0`), dragging downward anywhere on the drawer sheet (top handle, app grid, or bottom edge) initiates a **1:1 physical downward pull of the entire drawer sheet** (`translate3d(0, ${dragDown}px, 0)`).
  - The wallpaper dimming smoothly reduces in real-time, revealing the clean Homepage (clock, date, search bar, and permanent 4 dock apps) underneath.
  - **Release Physics**:
    - If pulled down past threshold ($> 35\text{px}$) or flicked down, the entire drawer sheet fluidly slides down off-screen and closes BOTH the drawer AND the rails, returning directly to the clean Homepage with Dynamic Island confirmation.
    - If released before threshold, elastic spring physics snap the drawer back up into open position.
  - **Zero Side-Rail Flash Guarantee (Silent Retraction)**:
    - To eliminate the visual glitch where side rails briefly flashed into view and animated into the bezels when returning to the Homepage, `dismissDrawerToHome()` employs a transition freeze mechanism.
    - While the drawer translates downward, `style.transition = 'none'` and `style.opacity = '0'` are applied during the class reset (`.drawer-mode` removed, `.retracted` added). A forced reflow (`void railLeft.offsetWidth`) ensures the off-screen docked position is committed instantly without animation before transitions and opacity are restored in `requestAnimationFrame`.
  - **In-List Scrolling**: If scrolled down inside the 40 apps (`drawerScrollOffset < 0`), dragging down scrolls the apps back up to the top; reaching the top seamlessly continues into the sheet pull-down.
  - **Alternative Dismissals**: Tapping the top titanium handle, clicking any background area outside the drawer, or launching an app executes `dismissDrawerToHome(true)`. Swiping outward horizontally separates the merged drawer back into the docked side rails.

### 3.3. Corner Radial Quick-Settings Arc
- **Geometry**:
  - Anchored at bottom-left $(0, 330)$ and bottom-right $(330, 330)$ corner coordinates.
  - Flush with the 34px bezel curvature of the Poco F1 chassis.
- **Spoke & Ring Layout**:
  - 3 concentric tier rings: Inner ($r=80\text{–}151\text{px}$), Middle ($r=151\text{–}223\text{px}$), Outer ($r=223\text{–}295\text{px}$).
  - 6 revolving spoke columns at $30^\circ$ steps with continuous rotary wrap-around.
- **Rotary Dial Interaction**: Rotational dragging around the corner origin rotates the spoke matrix. Standalone round NOTIF hub nestled inside the corner curve triggers the notification center.

### 3.4. Quick Settings 3D Rolodex Notification Deck
- **Placement**: Centered in the middle zone (`top: 238px; left: 14px; right: 14px; height: 130px;`) between the status HUD and bottom arc.
- **Vertical 3D Rolodex Kinematics (Android 5.0+ Lollipop/Nougat Recents Style)**:
  - 3D CSS spatial transforms (`perspective: 900px; perspective-origin: 50% 85%`).
  - Active and queued cards ($rel \ge 0$): Tilts backward along the X-axis (`rotateX: rel * 15deg`), cascades upward along Y (`translateY: -rel * 26px`), and recedes in depth (`translateZ: -rel * 62px`).
  - Discarded / preceding cards ($rel < 0$): Peels forward and downward (`translateY: rel * 88px`, `rotateX: -rel * 32deg`, `translateZ: |rel| * 45px`).
- **Autonomous & Direct Controls**:
  - Auto-flips forward vertically every 2.0 seconds (`SPATIAL_SLIDE_DURATION = 2000`) when idle.
  - Pauses automatically during touch gestures, pointer drags, and cursor hover with race-condition-free timer cancellation.
  - Manual vertical swiping: swiping UP ($dy < -30\text{px}$) flips forward; swiping DOWN ($dy > 30\text{px}$) flips backward.
- **Minimalist Indicators**:
  - Count $\le 3$: Renders exact count of small 5px circular dots (`.spatial-indicator-dot`).
  - Count $> 3$: Renders exactly 3 dots plus 1 horizontal line pill (`.spatial-indicator-line`, 14×3px) representing overflow.

### 3.5. Edge-to-Edge Notification Center
- **Layout**: Full-screen drop-down sheet extending from the status bar down to the bottom bezel.
- **Direct Manipulation**:
  - Pulled down 1:1 from the top status bar.
  - Dismissed by swiping up from the bottom home indicator bar or header.
  - Horizontal swipe-to-dismiss on individual notification cards with Dynamic Island alert and real-time state synchronization with Quick Settings.
- **Zero Scrollbars**: Native overflow scrolling without visual scrollbar bars (`scrollbar-width: none; ::-webkit-scrollbar { display: none; }`).

### 3.6. Dynamic Island Architecture: Flawless Physical Notch Seam Emergence & Content Matrix
- **Physical Notch Reality**:
  - The Xiaomi Poco F1 (`beryllium`) features an authentic wide physical "bathtub" notch cutout (`width: 188px; height: 28px;` in 360 CSS px, $x = 86\dots 274\text{px}$) containing physical plastic and hardware sensors (20MP camera, IR face unlock illuminator, earpiece slit).
  - **Zero Software Drawing Over Notch**: On a physical device, no pixels exist in the notch. The center hardware notch remains completely untouched with zero software pixels. On mobile viewport (`@media (max-width: 600px)`), the desktop simulated notch is hidden (`display: none !important`) so the phone's physical hardware sits naturally between the screen horns.
- **Physical Notch Seam Kinematics (Zero Fade-In / Liquid Slide)**:
  - **No Fade-In / Fade-Out**: Rather than generic opacity popping, the wings physically **slide out from behind the left and right walls of the notch** and **retract directly back inside the notch seams**.
  - **Seam Boundary Clipping**:
    - Left Horn (`.status-horn-left`): `clip-path: inset(-20px 0px -20px -20px);`. Strictly clipped at the right wall ($x = 86\text{px}$). Idle state is tucked at `transform: translateX(78px)` (inside notch). Active state slides left to `transform: translateX(0)` into the left ear.
    - Right Horn (`.status-horn-right`): `clip-path: inset(-20px -20px -20px 0px);`. Strictly clipped at the left wall ($x = 274\text{px}$). Idle state is tucked at `transform: translateX(-78px)` (inside notch). Active state slides right to `transform: translateX(0)` into the right ear.
  - **Tactile Clock & Battery Displacement**:
    - As the Left Wing emerges out of the notch seam to the left, it smoothly pushes the Clock off-screen (`translateX(-32px)`).
    - As the Right Wing emerges out of the notch seam to the right, it smoothly pushes the Battery/Wi-Fi off-screen (`translateX(32px)`).
    - When the 2.2s alert expires, the wings slide back into the notch seams, and Clock/Battery glide back into place.
- **Content Fitting Matrix (What Fits In Both Wings)**:
  - **Left Wing (App Pod)**: Spans $67\times 22\text{px}$ ($x = 15\dots 82\text{px}$). Houses $14\times 14\text{px}$ 18k champagne gold app glyph + Title text (`font-size: 8.5px; font-weight: 700; max-width: 40px`). Fits up to 8 characters with precision ellipsis.
  - **Right Wing (Status Pod)**: Spans $67\times 22\text{px}$ ($x = 278\dots 345\text{px}$). Houses uppercase status pill (`font-size: 8px; font-weight: 800; letter-spacing: 0.04em; max-width: 58px`). Fits up to 11 characters.

| Trigger Event | Left Wing (App Glyph + Title) | Right Wing (Status Pill) | Behavior / Action |
| :--- | :--- | :--- | :--- |
| **Wi-Fi Toggle** | `[Wi-Fi Icon] Wi-Fi` | `CONNECTED` / `OFF` | Spoke tap; immediate radio toggle |
| **Bluetooth Toggle** | `[BT Icon] Bluetooth` | `PAIRED` / `DISABLED` | Spoke tap; device connection status |
| **Hotspot Toggle** | `[Hotspot Icon] Hotspot` | `ACTIVE` / `DISABLED` | Spoke tap; AP broadcast state |
| **DND Zen Toggle** | `[Moon Icon] DND Zen` | `PRIORITY` / `NORMAL` | Spoke tap; notification filter mode |
| **Cloud Sync** | `[Cloud Icon] Sync` | `LIVE SYNCED` | Spoke tap; repository state sync |
| **Screen Record** | `[Rec Icon] Record` | `1080P 60FPS` | Spoke tap; encoder buffer active |
| **Flashlight / Torch** | `[Torch Icon] Torch` | `LIGHT ON` / `OFF` | Spoke tap; rear LED activation |
| **Sound / Volume** | `[Speaker Icon] Audio` | `NORMAL` / `SILENT` | Spoke tap; audio sink profile |
| **Notification Action** | `[App Icon] Terminal / Git` | `UPDATING` / `DIFFING` | Action button tap in notif card |
| **Notification Dismiss** | `[App Icon] App Name` | `DISMISSED` | Card swipe or dismiss button tap |
| **Clear All Notifs** | `[Bell Icon] Notifs` | `ALL CLEARED` | Top action pill in Notification Center |
| **Open Notif Center** | `[Bell Icon] Notifs` | `CENTER OPEN` | Notif button or status horn tap |
| **Permanent Dock Launch** | `[App Icon] App Name` | `OPENING...` | Spring depression on dock icon |
| **Web Browser Tab** | `[Globe Icon] Browser` | `OPEN URL...` | Search pill tap on home screen |

---

## 4. Wayland Compositor Integration (`wlr-layer-shell`)

In the native Linux Wayland session, each ButterOS UI element maps to a dedicated Wayland Layer Shell surface:

| ButterOS Component | Wayland Protocol Role | Layer | Anchors & Exclusive Zone |
| :--- | :--- | :--- | :--- |
| **Wallpaper Canvas** | `zwlr_layer_shell_v1` | `BACKGROUND` | Left, Right, Top, Bottom (No input focus) |
| **Dual Edge Rails** | `zwlr_layer_shell_v1` | `BOTTOM` | Anchored to Left (`width: 76px`) and Right (`width: 76px`) |
| **Merged App Drawer** | `zwlr_layer_shell_v1` | `TOP` | Centered full surface with touch gesture grab |
| **Corner Radial Arc** | `zwlr_layer_shell_v1` | `OVERLAY` | Bottom corners; exclusive pointer input when active |
| **3D Rolodex Deck** | `zwlr_layer_shell_v1` | `OVERLAY` | Centered sub-surface in Quick Settings session |
| **Notification Center** | `zwlr_layer_shell_v1` | `OVERLAY` | Full-screen (`inset: 0`); exclusive input grab |
| **Dynamic Island** | `zwlr_layer_shell_v1` | `OVERLAY` | Top notch anchor; auto-collapsing overlay HUD |

---

## 5. System Daemons & IPC Map (D-Bus)

The shell interfaces with standard Linux mobile daemons over the system D-Bus:

- **Telephony & Cellular Data**:
  - `ModemManager` at `org.freedesktop.ModemManager1`
  - Interfaces with Qualcomm Snapdragon X20 LTE baseband via `/dev/qrtr-radix` (Qualcomm IPC Router).
  - Handles SIM status, cellular signal strength, incoming/outgoing calls, and mobile data bearer activation.
- **Audio Routing**:
  - `PipeWire` 1.0 + `WirePlumber` with ALSA UCM profiles for Qualcomm QDSP6.
  - Dynamically routes between the Poco F1 earpiece speaker, bottom loud speaker, and 3.5mm analog audio jack.
- **Power & Fuel Gauge**:
  - `UPower` monitoring `/sys/class/power_supply/battery` (Qualcomm SMB1355 / PMIC fuel gauge).
- **Haptics**:
  - `feedbackd` at `org.sigxcpu.Feedback` driving the Poco F1 LRA vibration motor via `/sys/class/leds/vibrator`.

---

## 6. Build, Packaging & Flashing Pipeline

### 6.1. Rootfs & Kernel Build with `pmbootstrap`
postmarketOS tooling (`pmbootstrap`) provides the packaging pipeline for `xiaomi-beryllium`:

```bash
# 1. Initialize environment targeting the Poco F1 with no default desktop
pmbootstrap init
# Target Vendor: xiaomi
# Target Device: beryllium
# Architecture: aarch64
# User interface: none

# 2. Build kernel and base packages
pmbootstrap build linux-xiaomi-beryllium

# 3. Build and package the ButterOS shell from local source
pmbootstrap build --src="$PWD" butteros-shell

# 4. Generate rootfs image with ButterOS included
pmbootstrap install --add butteros-shell
```

### 6.2. Package Definition (`APKBUILD`)
Local package recipe placed in the aports tree:

```sh
# Maintainer: ButterOS Core Team
pkgname=butteros-shell
pkgver=1.0.0
pkgrel=1
pkgdesc="ButterOS Shell and Wayland compositor for Xiaomi Poco F1"
url="https://github.com/butteros/butteros"
arch="aarch64"
license="MIT"
depends="mesa-dri-gallium pipewire wireplumber modemmanager iwd feedbackd"
makedepends="wlroots-dev wayland-dev meson ninja"
subpackages="$pkgname-openrc"
# Source built from local source repository checkout
source=""

build() {
    meson setup --prefix=/usr build
    ninja -C build
}

package() {
    DESTDIR="$pkgdir" ninja -C build install
    install -Dm755 butteros.initd "$pkgdir"/etc/init.d/butteros
}
```

### 6.3. Poco F1 Partitioning & Flashing Realities
The Xiaomi Poco F1 is a **non-A/B** Android device with standard Qualcomm partition layout:
- `boot` partition (64 MB): Holds the Android-format `boot.img` (kernel + initramfs + appended DTB).
- `system` partition (~3 GB) and `userdata` partition (~50 GB+).

Because stock Xiaomi ABL fastboot can choke on large sparse images when flashing rootfs directly to `userdata`, the two reliable deployment routes are:

#### Method A: Fastboot Deployment (Standard)
```bash
# Export generated images
pmbootstrap export

# Flash kernel to boot partition
fastboot flash boot /tmp/postmarketOS-export/boot.img

# Flash system image to userdata
fastboot flash userdata /tmp/postmarketOS-export/xiaomi-beryllium.img

fastboot reboot
```

#### Method B: Android Recovery ZIP (Recommended for First Bring-up)
If fastboot fails on large sparse allocations:
```bash
# Generate a flashable recovery ZIP
pmbootstrap install --android-recovery-zip

# Flash via TWRP / OrangeFox recovery or sideload:
adb sideload /tmp/postmarketOS-export/pmOS-xiaomi-beryllium.zip
```

---

## 7. Hardware Bring-up Validation Checklist

| Target Subsystem | Verification Command on Target Device | Acceptance Criteria |
| :--- | :--- | :--- |
| **KMS / Direct DRM** | `modetest -M msm` | Primary connector `DSI-1` reports `connected` at 1080×2246 |
| **GPU Acceleration** | `es2_info \| grep "GL_RENDERER"` | Reports `FD630` (Adreno 630 Freedreno driver) |
| **Touchscreen Digitizer** | `evtest /dev/input/eventX` | Reports multi-touch ABS_MT coordinate events across 1080×2246 bounds |
| **Wayland Compositor** | `wayland-info` | `zwlr_layer_shell_v1` and `xdg_wm_base` globals advertised |
| **LTE Modem** | `mmcli -m 0` | Modem state reports `registered` or `connected` |
| **Audio Routing** | `pw-play /usr/share/sounds/test.wav` | Audible output routed through speaker/headphone jack |
| **Linear Haptics** | `echo 100 > /sys/class/leds/vibrator/duration && echo 1 > /sys/class/leds/vibrator/activate` | LRA motor executes tactile pulse |
| **Thermal & Current** | `cat /sys/class/power_supply/battery/current_now` | Valid mA reading reported by SMB1355 fuel gauge |
