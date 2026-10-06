# Chronological User Prompts, Directives & Brainstorming Log

This document preserves the authentic chronological progression of user directives, design critiques, hardware discoveries, and architectural brainstorming conducted across **Antigravity** and **Claude** during the development of **ButterOS on the Xiaomi Poco F1 (`beryllium`)** (September – October 2026).

---

## 📅 Phase 0: Pre-Inception, Gaming & Apple HIG Research (Sept 21–25, 2026)

### 1. GameHub & ARM64 Translation Layers (Sept 21–22):
* **Context**: Testing high-performance gaming translation layers on the Snapdragon 8 Elite (Realme GT 8 Pro).
* **Directives**:
  > *"Installed GameHub, downloaded Arkham Knight and tried to launch in GameHub... FitGirl repack, USB debugging on... Streaming over ADB."*
  - Investigated Box64/FEX-Emu, Turnip Vulkan drivers, and direct storage container mappings on ARM64.

### 2. Apple HIG & Liquid Glass Physics Research (Sept 24):
* **Context**: Researching Apple Human Interface Guidelines and modern iOS 17/18 fluid interaction standards.
* **Directives**:
  > *"Research Apple Human Interface Guidelines and modern iOS Liquid Glass design specifications for notification center, gesture dynamics, spring animations, and 3D rolodex spatial interaction."*
  - This research directly produced the physical spring parameters ($F = -kx - cv$) and luxury champagne gold materials implemented in ButterOS.

---

## 📅 Phase 1: Inception, UI Prototyping & Antigravity Bring-up (Sept 26–28, 2026)

### The Inception Moment (Sept 26, 2026):
> *"CAN I MAKE LIKE LINUX ON ARM FEDORA TYPE FOR SD845 POCO F1?"*  
> *"SO IN 2ND PLAN THE LINUX DISTRO WILL BE MINE?"*  
> *"BUT I HAVE AN INFINIX AIR PRO PLUS AS LAPTOP"*

### The 7-Subagent Research Marathon (Sept 26, 2026):
1. **Kernel Specialist**: SDM845 mainline Linux kernel and device tree constraints.
2. **Graphics Specialist**: Mesa Freedreno/Turnip GPU acceleration + Labwc Wayland kiosk.
3. **Audio Specialist**: TAS2559 DSP firmware, ALSA UCM2, and PipeWire integration.
4. **Modem Specialist**: Snapdragon X20 LTE cellular router (QRTR / RMTFS) and WCN3990.
5. **Debootstrap Specialist**: Debian 13 (Trixie) ARM64 rootfs packaging.
6. **Dual-Boot Architect**: Non-destructive loopback container (`/data/butteros/rootfs.img`).
7. **Mesa/GPU Specialist**: Adreno 630 Turnip Vulkan 1.3 compatibility.

### Core User Directives & Feedback:
1. **The Vision**:
   > *"I want an ultra-smooth, high-performance Linux mobile OS for the Poco F1. No heavy Android bloat, but giving it an iOS type of touch with Linux on steroids level smoothness and features."*
2. **Real-time Deployment & Gadget Mode**:
   > *"Install handheld mode and fix live time. Can we edit UI realtime and also work on our OS realtime from that? DUDE USE YOUR GADGET MODE."*
   - Engineered ConfigFS USB Gadget mode with Android Bionic `adbd` running under Debian 13 arm64.
3. **UI Scaling & Touch Critiques**:
   > *"FOR STARTERS. IT SAYS 1:48 RIGHT NOW. AND RAILS ARE ON. CAN'T SWIPE, CAN SCROLLS. CAN TAKE ICONS."*
   > *"Dude the rails are invisible. It's not working. Fake icons. Fake icons. Fake UI. Make everything working."*
   > *"Needs resizing, icons doesn't open. Not setting even quick tiles doesn't work. Doesn't go to settings or any apps. Like wtf bruh."*
   > *"Also there's not a pause after rail to app drawer as we discussed with a vibration. Also the device is getting heated a lot. Why we don't want that."*
4. **App Integration & Touch Handling**:
   > *"Don't start with rails on, also when drawer is pushed back, go back to home screen, not rails. Also for the last fuckin time, icons pressing doesn't do shit."*
   > *"Now touch isn't working at all... Dude it's asking for login wtf, remove that. Still asking for ID and password bruh, and there's no keyboard."*
   > *"Dude there's no back swiping if I took into app, the browser is in desktop mode. The same thing swipe that opens rail can function as back button like in android if inside any apps."*

### Key Antigravity Milestones:
* Created non-destructive 6GB–8GB loopback image at `/data/butteros/rootfs.img` on Android `/data`.
* Configured `Labwc` (wlroots 0.18 layer-shell kiosk) running Chromium Wayland on `/dev/dri/card0`.
* Solved touchscreen event dropping via `/etc/udev/rules.d/99-pocof1-touchscreen.rules`.
* Authored `butteros_project_handoff.md` and `implementation_plan.md` for cross-harness continuity.

---

## 📅 Phase 2: Handoff to Claude & Hardware Deep-Dive (Sept 28–30, 2026)

### Transition Prompt:
> *"DUDE JUST GIVE ME THE PROJECT DETAILS, WHAT HAVE DONE TILL NOW. DIRECTORIES AND I'LL MOVE TO ANOTHER AI HARNESS. NOW GIVE INSTRUCTIONS TO HANDOVER, WITH HOW TO GO BACK TO ORIGINAL BOOT."*

### Hardware Bring-up & Networking:
1. **USB Serial Console Pipeline (COM5)**:
   - Built `phone-run.ps1` and `deploy-shell.ps1` streaming `debian-butteros/shell/shell.html` directly over 115200 baud serial in ~5 seconds with MD5 verification, eliminating the need to reboot into recovery for UI tweaks.
2. **Wi-Fi Connectivity**:
   > *"Well either you connect for me, or give me a keyboard on Poco F1... Password is maheswar, and the Wi-Fi is the one we connected in this laptop realme g 8 pro."*
   - Discovered Wi-Fi hotspot SSID had a crucial **trailing space** (`"realme GT 8 Pro "`). Built `connect-wifi.ps1` to join automatically via NetworkManager.
3. **Display Scaling & Mobile App Sizing**:
   > *"Also browser is not phone sized too. Apps are not loading properly. Even music."*
   - Root cause: GTK4 / Libadwaita apps ignore `GDK_SCALE` on Wayland and follow compositor output scale.
   - Fix: Executed `wlr-randr --output DSI-1 --scale 3` in `butteros-session.sh`. Dropped Chromium force-scale flag. Native mobile apps now render crisply at 360 logical px wide.

---

## 📅 Phase 3: Sensory Polish, Gestures & The Audio Breakthrough (Sept 29–30, 2026)

### Interaction Feel Directives:
1. **Detents & Haptics**:
   > *"Actually we need a pause after we hit the rails with a vibration, then moves to the app drawer with a bit more swiping effort. All optimized maxed and smooth as shell."*
   > *"Now when I go from rail to drawer it creates a black screen on both sides. Also if we skipped way past mid line then go directly to drawer. Also make every tile in quick settings workable."*
2. **System Gestures (lisgd)**:
   > *"Swipe up from down to up from middle is recent apps. Give it that Android touch overall. Left/right edge swipe for back."*
   - Implemented bottom short swipe for Home, bottom long swipe for Recents, 2-finger swipe up for Virtual Keyboard (`squeekboard`/`wvkbd`), edge swipe for Back, and top swipe for Notifications.
3. **Panels Over Native Apps**:
   - Built a layer-shell workflow: `lisgd` triggers `grim` to capture the underlying native app screen, raises the ButterOS shell with a blurred glassmorphic overlay, and seamlessly refocused the native app upon dismissal.

### The TAS2559 Audio Breakthrough:
* **User Feedback**:
  > *"Dude no voice in boot animation... No sound at all lol... No sound."*
* **Investigation & Breakthrough**:
  - Direct ALSA and `mpv` playback were completely silent even though PipeWire saw the sound card.
  - Kernel dmesg revealed that the Texas Instruments TAS2559 smart amplifier initializes with **Configuration 3 (Handset/Earpiece)** on audio stream start.
  - **The Solution**: Audio playback must begin *first*, immediately followed by dynamically invoking:
    `amixer -c0 cset name='Configuration' 4` (Loudspeaker profile `_s5_4`).
  - Routed speaker mixer: `QUAT_MI2S_RX Audio Mixer MultiMedia1=1`. Boot animation audio now roars through the speaker with zero distortion.

---

## 📅 Phase 4: Bootloader, Power Management & Battery Mysteries (Sept 30 – Oct 6, 2026)

### Dual-Boot Architecture:
1. **User Requirement**:
   > *"Create dual boot at first. Like a grub... No no I want a grub like interface, which chooses the boot first... Put it before boot animation, so Linux is basically loaded and allows to move to Android partition."*
2. **Implementation**:
   - Designed interactive framebuffer boot menu (`butteros-bootmenu.py` with pre-rendered graphical frames).
   - 8-second countdown timer controllable via Volume Keys, Power Button, or touchscreen.
   - Dual-boot switching: Setting/Power menu triggers `butteros-boot-switch.sh`, swapping between stock Android boot (`stock_boot_raw.img`) and ButterOS quiet boot image. Return to ButterOS via OrangeFox flashable zip `/data/butteros/switch-to-butteros.zip`.

### Power Key, Sleep & Watchdog:
1. **User Feedback**:
   > *"Why can't you add like an option for that like 5 second of pressing power button shows options such as power off, reboot. Also we don't have volume up, down which shows animation of increasing decreasing."*
2. **Fixes**:
   - Masked systemd logind's default `HandlePowerKey=poweroff` which previously caused sudden shutdowns ("the stuck bug").
   - Implemented `butteros-powerkey.py`:
     - Short press (<0.4s): Display sleep/wake via backlight `bl_power` (avoiding `wlr-randr --off` which stalled KMS).
     - Long press (>1.0s): Opens full mobile power dialog (Power Off, Restart, Reboot to Android, Recovery).
     - Power + Volume Down: Captures instant screenshot via `grim`.
     - Volume Up/Down: Triggers visual on-screen volume OSD slider.

### Battery Diagnostics & Charging Limits:
1. **User Directives**:
   > *"I think we have an issue where charging is not working, it stays same or slow... It's shutting down. It shows 1250mA to 1350mA in wall charger. Still nothing is increasing. I changed battery 2 months ago."*
2. **Root Cause Analysis**:
   - Hardware battery health verified at **99.7%** (fuel gauge readings healthy).
   - On host PC/laptop USB ports, the Linux mainline battery charger driver strictly enforces a **25mA** safety limit (preventing charging while connected to dev laptops).
   - On dedicated 5V wall chargers, current ramps up to **+2.2A** in Android.
   - Deployed battery monitoring daemon (`/var/log/butteros-battery.csv`, sampling voltage, current, and SoC every 30s) to monitor live charging behavior under ButterOS.
3. **Idle Drain Investigation**:
   - Screen-off idle consumption measured at 140mA–450mA because deep suspend is not yet active (Chromium, GPU, and network remain fully awake).

---

## 📅 Phase 4.5: Cross-Project Engineering, Horizon Game & Laptop Fixes (Sept 30 – Oct 3, 2026)

During the stabilization of ButterOS, parallel engineering sessions addressed interrelated tooling, mobile hardware, and creative pipelines:

### 1. TELEIO HORIZON 2.5D Game Development (Sept 30 – Oct 2):
* **Context**: Crafting an original 2D/2.5D game without pure generative image clutter, focusing on responsive physics and custom characters.
* **Directives**:
  > *"I saw you making a 2/2.5D without generating images and neat? How did you do that... Yeah draw Mario let me see... C:\Games\GAMEDEV\HORIZON and C:\Games\GAMEDEV\HORIZON_SOURCES play this and tell how it's moving, if it's interesting."*
* **Architecture**: Built custom sprite pipelines, dynamic camera interpolation, and physics-driven character controllers deployed to `MaheswarPraveen/teleio-horizon-demo`.

### 2. Prime Max Mobile Rewards Platform (Oct 1–3):
* **Context**: Architectural planning for an educational ad-rewards application with strict security and revenue modeling.
* **Directives**:
  > *"I need to build an experimental educational app where people can see ads from Google or any other sources, get coins and then redeem as money... We need both iOS and Android, and should have security... What will be the estimated revenue if one person saw ads for 1 hour?"*
* **Architecture**: Engineered fraud prevention, simulated token economies, and multi-tier ad network aggregation deployed to `MaheswarPraveen/prime-max`.

### 3. Infinix Air Pro Plus Diagnostics & Howdy IR Unlock (Sept 30 – Oct 3):
* **Context**: Restoring development host stability after jumping between Linux and Windows.
* **Directives**:
  > *"My keyboard in this Infinix Air Pro Plus isn't working. Buttons such as W, E, R, Y, Enter, Windows, K, L aren't working... Also my Howdy face unlock doesn't work after I jumped to Linux and back to Windows... Set up for me please."*
* **Fixes**: Re-initialized Windows I2C/HID filter drivers, repaired Howdy IR PAM modules and video capture nodes (`/dev/video*`), and eliminated background resource hogs.

---

## 📅 Phase 5: Synthesis & Handover Directives (Oct 6–8, 2026)

### User Request:
> *"Create a butteros.md in desktop path for me to continue the project in new claude account. It should have necessary stuff."*
> *"No it missed several prompts and brain storm I did over last month. Find it fix it and upload it appropriately."*
> *"what about September 21st to oct 3rd"*

### Resulting Consolidated Knowledge:
All prompt streams, working rules, hardware discoveries, and architectural solutions have been synthesized into this repository's `docs/` and synced with the central `thoughts` architecture corpus.
