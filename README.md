# ButterOS: Debian 13 (Trixie) Mobile Linux for Xiaomi Poco F1 (`beryllium`) 📱🐧⚡

A native bare-metal GNU/Linux mobile operating system for the **Xiaomi Pocophone F1 (Qualcomm Snapdragon 845 / Adreno 630)**, powered by **Debian 13 (Trixie) ARM64**, **Labwc (wlroots) Wayland kiosk compositor**, **Mesa 25 Freedreno/Turnip GPU acceleration**, and the bespoke **ButterOS Mobile Shell**.

Co-engineered with **Antigravity** and **Claude** as a dedicated mobile Linux research and daily-driver exploration project.

---

## 🎯 Architecture & System Stack

```
┌────────────────────────────────────────────────────────────────────────┐
│  BUTTEROS MOBILE SHELL (HTML5 / CSS / WebGL Kiosk)                     │
│  - Dual Perimeter Rails (Continuous 40-app conveyor & dock)            │
│  - 12-Spoke 360° GPU Matrix Rotary Quick Settings (120 FPS free-wheel) │
│  - Full A-Z Searchable App Drawer & 1:1 Swipe-Down Gestures            │
│  - 3D Rolodex Spatial Notification Deck & System Status Badges         │
│  - Auth: Per-boot cryptographic token (BUTTEROS_BRIDGE_TOKEN)          │
├────────────────────────────────────────────────────────────────────────┤
│  WAYLAND COMPOSITOR & GRAPHICS (Labwc 0.8.3 / wlroots 0.18)            │
│  - Compositor: Labwc Layer-Shell Kiosk on Wayland                      │
│  - GPU Acceleration: Mesa 25 Turnip Vulkan 1.3 + Freedreno GLES        │
│  - Panel Tuning: wlr-randr --output DSI-1 --scale 3                    │
│  - Jitter Fix: WLR_SCENE_DISABLE_DIRECT_SCANOUT=1                      │
│  - Mobile Gestures: lisgd (bottom-edge swipe up = home/recents)        │
│  - Virtual Keyboards: squeekboard (auto-popup) / wvkbd-mobintl         │
├────────────────────────────────────────────────────────────────────────┤
│  HARDWARE BRIDGE & SERVICES (Python 3 + systemd)                       │
│  - Native Bridge: butteros-bridge.py (Port 9090, token-authenticated)  │
│  - Notifications: butteros-notifyd (org.freedesktop.Notifications)     │
│  - Audio Engine: PipeWire 1.4.2 + WirePlumber + ALSA UCM2 (beryllium)  │
│  - Smart Amp: TAS2559 dynamic tuning profile routing (Speaker Conf 4)  │
│  - Cellular & Modem: ModemManager + QRTR Router + RMTFS                │
│  - Connectivity: NetworkManager + wpa_supplicant + bluez               │
│  - Hardware MAC: Synthesized Bluetooth/Wi-Fi MAC injector script       │
│  - Power & Watchdog: swayidle 60s screen-off + butteros-powerkey       │
├────────────────────────────────────────────────────────────────────────┤
│  BASE OS & KERNEL                                                      │
│  - Kernel: Mainline Linux 6.6+ / 7.1.0-rc1-sdm845                      │
│  - Distribution: Debian GNU/Linux 13 (Trixie) arm64                    │
│  - Container: Non-destructive 6GB loopback image (/data/butteros)      │
│  - User: butter (passwordless sudo enabled)                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📱 Hardware Support Matrix (Snapdragon 845 / Beryllium)

| Component | Hardware / Driver | Status | Notes |
| :--- | :--- | :---: | :--- |
| **SoC** | Qualcomm Snapdragon 845 (8x Kryo 385) | ✅ Working | Full CPU frequency scaling & multi-core topology |
| **GPU** | Adreno 630 (Mesa 25 Freedreno / Turnip) | ✅ Working | Hardware accelerated GLES & Vulkan |
| **Display** | Tianma FHD+ 1080x2246 (`dsi_tianma_fhd`) | ✅ Working | Driven at 3x logical scale via `wlr-randr` |
| **Touchscreen** | Novatek NT36672A (`nt36672a-ts`) | ✅ Working | Forced udev touchscreen classification |
| **Audio (Speaker)** | TAS2559 Smart Amplifier + WCD9340 | ✅ Working | Fixed via ALSA route + `Configuration 4` trigger |
| **Audio (Jack)** | Headset Jack Detection | ✅ Working | Standard ALSA event handler |
| **Wi-Fi** | Qualcomm WCN3990 (ath10k_snoc) | ✅ Working | Firmware loaded, NetworkManager client active |
| **Bluetooth** | Qualcomm WCN3990 (hci_qca) | ✅ Working | Synthesized MAC address injection |
| **Modem / RIL** | Snapdragon X20 LTE (QRTR / RMTFS) | ⚠️ Partial | RemoteFS and TFTP active; ModemManager hooked |
| **Power Button** | PM8941 PMIC Power Key (`pm8941_pwrkey`) | ✅ Working | Short press = display sleep, long press = power menu |
| **Watchdog** | Qualcomm Hardware Watchdog (`qcom_wdt`) | ✅ Working | System supervised, safe poweroff at 3% battery |
| **Dual Boot** | Android CloverOS (Stock) + Debian ButterOS | ✅ Working | 8-second interactive bootloader selection |

---

## 🛠️ Solved Engineering Challenges

### 1. TAS2559 Smart Amplifier Loudspeaker Routing
* **Problem**: The onboard Texas Instruments TAS2559 smart amplifier initializes with Configuration 3 (Earpiece), causing speaker playback to remain completely silent during direct ALSA / boot animation runs.
* **Fix**: The audio stream must be initiated first, followed immediately by setting `amixer cset name='Configuration' 4` (Loudspeaker profile `_s5_4`) with small buffers (`--audio-buffer=0.06`) and routing `QUAT_MI2S_RX Audio Mixer MultiMedia1=1`.

### 2. Touchscreen Event Dropping & Classification
* **Problem**: `libinput` dropped `nt36672a-ts` touch events or treated them as an absolute mouse tablet.
* **Fix**: Added `/etc/udev/rules.d/99-pocof1-touchscreen.rules` forcing `ENV{ID_INPUT_TOUCHSCREEN}="1"`, `ENV{WL_OUTPUT}="DSI-1"`, and clearing mouse/tablet environment flags.

### 3. Wayland & DRM Render Node Permissions
* **Problem**: GTK4 / Libadwaita apps crashed with `DRM_IOCTL_MODE_CREATE_DUMB failed: Permission denied`.
* **Fix**: Configured `butter` user membership in `video` and `render` groups, unsetting conflicting `MESA_LOADER_DRIVER_OVERRIDE` when launching native apps, and using `GSK_RENDERER=ngl` / `cairo` fallback.

### 4. FastRPC & SLPI Crash Loop Prevention
* **Problem**: SLPI (Sensors Low Power Island) experienced continuous watchdog resets (`crash #71 in slpi`), causing battery drain and shutdown hangs.
* **Fix**: Soft-dependency ordering for `pd-mapper` and blacklisting unstable FastRPC probe loops in `/etc/modprobe.d/butteros.conf`.

### 5. Bridge Security & Per-Boot Tokens
* **Problem**: Unauthenticated local web requests in Chromium could theoretically invoke arbitrary commands on the system bridge.
* **Fix**: Added a per-boot 32-byte cryptographic token (`BUTTEROS_BRIDGE_TOKEN`) generated in `butteros-session.sh` and passed via URL hash (`#t=...`). Requests without the valid session token are rejected.

---

## ⚡ Developer & Live Deployment Workflow

ButterOS includes a comprehensive suite of PowerShell automation tools for managing the phone directly from a Windows host over the **USB Serial Console (COM5)**:

### 1. Ultra-Fast UI Deployment (Hot Reload in ~5s)
Stream and deploy updates to the live shell without rebooting or entering recovery:
```powershell
.\deploy-shell.ps1 -Port COM5
```
* Transfers `debian-butteros/shell/shell.html` via base64 streaming over serial.
* Validates MD5 checksum on the target.
* Atomically backs up the previous shell to `shell.html.prev`.
* Gracefully restarts the Chromium kiosk instance without tearing down the Wayland session.
* Rollback anytime with: `.\deploy-shell.ps1 -Rollback`

### 2. Remote Command Execution over Serial
Execute arbitrary commands on the running phone and capture output:
```powershell
# Run default hardware diagnostic report:
.\phone-run.ps1 -Port COM5

# Run custom commands and save output:
.\phone-run.ps1 "uname -a; ip a; nmcli dev" -Out logs/network.log
```

### 3. Connect to Wi-Fi
```powershell
.\connect-wifi.ps1 -Port COM5 -SSID "YourNetwork" -Password "YourPassword"
```

### 4. Chrome DevTools Protocol (CDP) Inspection
```powershell
.\phone-cdp.ps1 -Port COM5 "document.title"
```

---

## 📂 Repository Structure

```
poco-f1-butter-os/
├── README.md                      # Primary project documentation
├── BUTTEROS_SPEC_SHEET.md         # Exhaustive hardware & OS specification
├── bootanimation.mp4              # Raw boot animation video (mpv DRM)
├── deploy-shell.ps1               # Hot-reload shell.html deployment tool
├── phone-run.ps1                  # Remote serial command executor
├── phone-cdp.ps1                  # Chrome DevTools Protocol automation
├── connect-wifi.ps1               # Wi-Fi credentials provisioning script
├── check-serial.ps1               # USB COM port discovery & diagnostics
├── install-file.ps1               # Push individual files over serial
├── push-all.ps1                   # Full system recovery push script
├── push-bootmenu.ps1              # Dual-boot bootloader menu deployer
├── push-dualboot.ps1              # Dual-boot kernel image deployer
├── push-hw.ps1                    # Hardware payload push script
├── push-step1.ps1                 # Initial setup bootstrap script
├── push-to-phone.ps1              # Transfer tarballs to device
├── debian-butteros/               # Core Debian 13 system implementation
│   ├── build/                     # Rootfs generators & build pipeline
│   │   └── build_debian_rootfs.sh # Automated ARM64 debootstrap script
│   ├── configs/                   # System configurations & services
│   │   ├── base/                  # Base setup script (butteros-base-setup.sh)
│   │   ├── bootanim/              # Boot animation systemd unit & scripts
│   │   ├── bootmenu/              # Dual-boot framebuffer UI
│   │   ├── dualboot/              # Dual-boot switching scripts
│   │   ├── gadget/                # USB ConfigFS configuration
│   │   ├── modprobe/              # Module blacklists & parameters
│   │   ├── notify/                # butteros-notifyd notification bridge
│   │   ├── power/                 # Powerkey daemon & swayidle rules
│   │   ├── systemd/               # Custom systemd unit files
│   │   ├── time/                  # Software RTC offset persister
│   │   ├── udev/                  # Touchscreen & MAC address udev rules
│   │   ├── usb/                   # USB serial console autologin service
│   │   ├── wayland/               # Labwc config, session script & gestures
│   │   └── butteros-bridge.py     # Hardware bridge HTTP daemon
│   ├── hw/                        # Hardware payload fetcher & extractor
│   ├── installer/                 # TWRP / OrangeFox flashable zip package
│   └── shell/                     # Production mobile shell
│       └── shell.html             # CANONICAL LIVE PRODUCTION SHELL
├── tools/                         # Maintenance & conversion utilities
│   ├── cdp.py                     # Headless CDP client
│   ├── make-switch-zip.py         # Dual-boot switch zip generator
│   ├── patch-bootimg-cmdline.py   # Kernel cmdline patching script
│   ├── render-bootmenu.py         # Framebuffer bootmenu renderer
│   └── legacy_patches/            # Archived one-off patch scripts (DO NOT RUN)
├── images/                        # Partition dumps & recovery images (gitignored)
├── logs/                          # Archived hardware debug output logs
├── docs/                          # Comprehensive technical & design documentation
│   ├── architecture/              # System architecture, specs & handoff manifests
│   │   ├── apple_hig_and_liquid_glass_spec.md # Apple HIG, Liquid Glass & spring physics spec
│   │   ├── butteros_handover_claude.md   # Complete Claude handover & operational guide
│   │   ├── butteros_project_handoff.md   # Antigravity technical architecture handoff
│   │   ├── butteros_spec_sheet.md        # Hardware and component specifications
│   │   ├── debian_butteros_walkthrough.md# Step-by-step Debian build walkthrough
│   │   └── implementation_plan.md        # Initial bring-up implementation plan
│   ├── brainstorm/                # Brainstorm logs, user directives & hardware analysis
│   │   ├── user_prompts_and_directives_log.md # Chronological prompt history & feedback
│   │   ├── battery_and_power_analysis.md      # Power, 25mA charging limit & thermal logs
│   │   └── kernel_and_hardware_roadmap.md     # Custom kernel & camera bring-up plans
│   └── screenshots/               # On-device photographs and interface captures
└── android-launcher/              # Standalone Android APK launcher prototype
```

---

## 📚 Technical Documentation & Brainstorm Corpus

* [**User Prompts & Directives Log**](./docs/brainstorm/user_prompts_and_directives_log.md): Complete chronological record of design critiques, haptic requests, touch scaling issues, and iterative directives from Sept 21 to Oct 8.
* [**Apple HIG & Liquid Glass Specification**](./docs/architecture/apple_hig_and_liquid_glass_spec.md): Foundational design research into Apple Human Interface Guidelines, spring animation physics ($F = -kx - cv$), and champagne gold materials.
* [**Battery & Power Diagnostic Analysis**](./docs/brainstorm/battery_and_power_analysis.md): In-depth breakdown of PMIC battery health (99.7%), laptop 25mA charging limit vs. wall charging (+2.2A), SLPI thermal runaway mitigation, and idle screen-off drain.
* [**Kernel & Hardware Roadmap**](./docs/brainstorm/kernel_and_hardware_roadmap.md): Strategic plan for building a custom mainline `sdm845` kernel, Sony IMX363 camera integration via `libcamera`/`udmabuf`, and 1-tap dual-boot switching.
* [**Claude Project Handover**](./docs/architecture/butteros_handover_claude.md): Operational guide detailing on-device loopback mount paths, USB serial commands, and runtime precautions.
* [**Antigravity Architecture Handoff**](./docs/architecture/butteros_project_handoff.md): Early architecture specification covering Labwc, Chromium kiosk flags, and ConfigFS USB gadget mode.

---

## 🔒 Non-Destructive Flashing (Zero Android Data Loss)

ButterOS installs entirely inside a dedicated **6GB ext4 loopback image** at `/data/butteros/rootfs.img`.
It **does not wipe**, **does not format**, and **does not touch** existing Android userdata, internal storage, or user apps.

### Flashing via OrangeFox / TWRP:
1. Boot phone into **OrangeFox Recovery** (`Power + Volume Up`).
2. Connect to PC and push the installer:
   ```powershell
   adb push debian-butteros/build/butteros-installer.zip /sdcard/
   ```
3. In OrangeFox, navigate to `/sdcard/` and flash `butteros-installer.zip`.
4. The installer creates `/data/butteros/rootfs.img`, extracts the Debian 13 root filesystem, and configures the dual-boot kernel.

---

## 📜 Credits & Acknowledgments

* **Qualcomm Mainline Linux Community**: SDM845 mainline kernel and device tree maintainers.
* **Labwc & wlroots Teams**: High-performance, low-overhead mobile Wayland kiosk compositor.
* **Debian Project**: Rock-solid Debian 13 (Trixie) ARM64 base.
* **Co-Engineered**: Antigravity + Claude + Maheswar Praveen.
