# ButterOS — project handover

ButterOS is a custom phone UI on Debian 13 (trixie) ARM64 for the **Xiaomi Poco F1** (codename beryllium, Snapdragon 845, Adreno 630). It runs as a Chromium kiosk showing one HTML shell, inside the **labwc** Wayland compositor. A local Python **bridge** lets the shell run real Linux commands.

The phone dual-boots with **Clover OS** (Android, not rooted).

---

## 1. Where things are (PC)

Project root: `C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\`

| Path | What |
|---|---|
| `debian-butteros\shell\shell.html` | **The UI.** About 7,500 lines: HTML, CSS and JS in one file. The only live copy; edit only this one. |
| `debian-butteros\configs\butteros-bridge.py` | HTTP bridge on 127.0.0.1:9090 (`/exec`, `/launch`, `/notifs`, `/state`, `/haptic`, `/ping`) |
| `debian-butteros\configs\wayland\butteros-session.sh` | Session startup: display scale, keyboard, lisgd gestures, bridge, Chromium loop, watchdog |
| `debian-butteros\configs\wayland\butteros-gesture.sh` | System gestures and panels over apps (back, notif, arcs, recents, volume) |
| `debian-butteros\configs\wayland\butteros-kbd.sh` | On-screen keyboard show/hide/toggle (squeekboard or wvkbd) |
| `debian-butteros\configs\power\` | Power key daemon, screen on/off, logind config, SLPI stop, battery logger |
| `debian-butteros\configs\bootanim\` | Boot animation (mp4, logo, player script, service) |
| `debian-butteros\configs\bootmenu\` | ButterOS/Android boot menu (python, service, pre-rendered frames) |
| `debian-butteros\configs\dualboot\butteros-boot-switch.sh` | Writes the Android or ButterOS boot image to the boot partition (verified) |
| `debian-butteros\configs\notify\butteros-notifyd.py` | freedesktop notification daemon, feeds the shell |
| `debian-butteros\configs\time\` | RTC offset fix (the phone's RTC is read-only, so the clock otherwise resets to 1970) |
| `debian-butteros\configs\modprobe\` | blacklist fastrpc (probe loop) and pd-mapper softdep |
| `debian-butteros\configs\base\butteros-base-setup.sh` | One-time package and service setup, run on the phone (idempotent) |
| `debian-butteros\build\` | `butteros-boot-quiet.img` (current boot image, no kernel text), `switch-to-butteros.zip`, boot partition backup |
| `debian-butteros\build_debian_rootfs.sh` | Full rootfs builder, used for fresh installs |
| `tools\` | `cdp.py` (DevTools client for the phone), `render-bootmenu.py`, `patch-bootimg-cmdline.py`, `make-switch-zip.py` |
| Stock Android boot image | `C:\Games\GAMEDEV\HORIZON_SOURCES\stock_boot_raw.img` |

**Never run** the legacy `patch_*.py`, `apply_shell_fixes.py` or `fix_syntax_and_cleanup.py`. They overwrite the live shell with stale copies.

## 2. On the phone

- ButterOS rootfs is a loop file: `/data/butteros/rootfs.img`, user `butter`, passwordless sudo.
- Shell: `/usr/share/butteros/shell.html`. Chromium loads it as `--app=file://…#t=<token>`.
- Bridge token: `/run/user/1000/butteros-bridge.token`. Every bridge call except `/ping` needs `&t=<token>`.
- Boot images inside the rootfs: `/usr/share/butteros/boot-images/{android,butteros}-boot.img`.
- Boot partition: `/dev/disk/by-partlabel/boot` (sde45).

## 3. How to reach the phone (from the PC)

| Situation | How |
|---|---|
| **ButterOS booted** | USB serial console **COM5** ("USB Serial Device"). Scripts: `phone-run.ps1` (run a command), `deploy-shell.ps1` (push the shell in about 5 s, md5-checked, `-Rollback` to undo), `install-file.ps1 -Src … -Dst …` (one file, md5-checked), `push-to-phone.ps1` (bundle to /tmp; its "PUSH FAILED" message is often a false alarm, so verify the md5), `phone-cdp.ps1 -Shot [-Screen]` (screenshot of the shell, or of the real screen via grim), `phone-cdp.ps1 -Eval "js"`. |
| **OrangeFox recovery** (Power + Volume Up) | `adb` works. Mount with `mount /dev/block/sda21 /data; mount -o loop /data/butteros/rootfs.img /mnt/butteros`. Scripts: `push-step1.ps1`, `push-dualboot.ps1`, `push-bootmenu.ps1`. |
| **Android (Clover OS)** | Wireless debugging: `adb connect 10.165.255.214:<port>`. The laptop is already paired; find the port with `adb mdns services`. |
| **Reboot to recovery from ButterOS** | `sudo systemctl reboot --reboot-argument=recovery` |

- Wi-Fi: the phone and laptop share the hotspot "realme GT 8 Pro " (the name has a **trailing space**). Use `connect-wifi.ps1`; the user types the password.
- Never `systemctl restart butteros-shell`: it kills only labwc and leaves two shells running. To reload the UI, kill the shell Chromium (`deploy-shell.ps1` does this). For anything bigger, reboot.
- Never `modprobe -r` a stuck module live. It hung shutdown and needed a forced restart. Blacklist it and reboot instead.

## 4. User's working rules

- **Additive changes only.** Don't rewrite working logic; mark changes with `// ADD-ON` (or `# ADD-ON`).
- **Sizes stay frozen** (scale 3, icon CSS, rail width 88 px) unless the user approves.
- **Preview before deploying:** serve `shell\` with `python -m http.server 8765`, open at 360×749, and test gestures with synthetic pointer events.
- The user writes informally and wants things done, not lists of options. Verify on the device (screenshots) rather than assuming.

## 5. What works (as of 2026-09-30)

- **Hardware:** Wi-Fi, Bluetooth (fixed address via bootmac from `qcom-phone-utils`), **GPU** (`firmware-qcom-soc`; renderer FD630), audio via PipeWire, modem detected, torch, clock (RTC offset).
- **Boot:** quiet boot image (no kernel text) → boot animation **with sound** → **boot menu** (8 s; ButterOS or Android; volume keys, power or tap) → logo held → shell fades in.
- **Display:** labwc output scale **3** (`wlr-randr` in the session). Chromium has no force-scale flag. GTK apps are phone-sized.
- **Apps:** GNOME apps launched with `env -u MESA_LOADER_DRIVER_OVERRIDE GSK_RENDERER=ngl …` (the override made them segfault): Calculator, Clocks, Files, Console, Photos (Loupe), Text Editor, Music (Amberol), Messages (Chatty), Phone (GNOME Calls), Contacts. Browser is a separate Chromium profile.
- **Shell features:**
  - rails with detent (snap and vibrate → pause → resistance → drawer; a fast swipe past the middle goes straight to the drawer)
  - drawer with a real scroll limit; stable icon order
  - 18 real quick tiles
  - real Settings; pages for Bluetooth, Battery, Storage, System and Log
  - lock screen; notifications (`notifyd` → bridge)
  - Recents (swipe up from the bottom middle)
  - power menu (hold power 1 s); volume OSD
  - live status-bar battery that trusts the actual current direction
  - **panels over apps:** grim snapshot → the shell raises with a blurred backdrop → the app is refocused when the panel closes
- **Gestures (lisgd):** bottom short = home, bottom long = recents, two-finger up = keyboard, left/right edge = back, top = notifications, bottom corners = quick-tile arcs.
- **Power:** short press toggles the screen (backlight off and touch grabbed), double-tap wakes, hold opens the power menu, power + volume-down takes a screenshot. 60 s idle turns the screen off.
- **Security:** the bridge needs a per-boot token and rejects web origins. Chromium's debug port is bound to 127.0.0.1.
- **Dual boot:** Settings or the power menu → "Restart to Android". It writes the stock boot image and reboots. **Back to ButterOS:** OrangeFox → Install → `/data/butteros/switch-to-butteros.zip`. Android stays the default boot until you switch back.

## 6. Key fixes and gotchas learned

- **Boot sound:** direct ALSA playback was silent because the TAS2559 amp loads its profile at stream start and picked **Configuration 3 = earpiece**. Fix: start playback, *then* `amixer -c0 cset name='Configuration' 4`. Use small buffers (`mpv --audio-buffer=0.06`). The speaker route is `QUAT_MI2S_RX Audio Mixer MultiMedia1`.
- The power key used to **power the phone off** (logind default). It's now `HandlePowerKey=ignore`, `HandlePowerKeyLongPress=ignore`.
- Screen off via `wlr-randr --off` stalled the msm driver. Use backlight `bl_power` only.
- The SLPI (sensor DSP) crash-looped because fastrpc is blacklisted (kernel 7.1 regression), so `butteros-slpi-off.service` stops it.
- The adbd gadget fought the serial console for the USB port and burned 300% CPU. It's disabled.
- **Charging:** the battery and hardware are fine (99.7% health). Slow charging came from the cable, charger or port; after the user changed something it reached about +2.2 A in Android at 5 V. On a laptop USB port the mainline charger driver only allows a 25 mA input limit. **Not yet tested:** ButterOS charging on the good wall charger. The battery logger `/var/log/butteros-battery.csv` (every 30 s) is there for that.

## 7. Open / next

1. Test ButterOS charging on the good wall charger and read `/var/log/butteros-battery.csv`. Fix the charger driver input limit if needed.
2. **Idle drain of 140–450 mA with the screen off:** there's no suspend; Chromium, GPU and display keep running. Pause work when the screen is off, or try suspend carefully (calls and alarms must still wake the phone).
3. Root Clover OS with Magisk, for a "Reboot to ButterOS" shortcut in Android.
4. Status bar that stays visible over apps; a true always-on-top overlay.
5. Own kernel build from the stable sdm845-mainline branch, test-booted with `fastboot boot` first. It would fix the fastrpc/sensor revert and the pd-mapper race, and give a stable kernel instead of 7.1-rc1.
6. iOS-level polish and smoothness: profile on the device through the Chromium debug port.
7. The boot animation video still says "ShyamOS". The user may want "ButterOS".
8. Camera: the rear IMX363 may work with libcamera and a udmabuf rule. Untested.

## 8. Safety / recovery

- Original boot backup: `debian-butteros\build\boot-partition-backup-20260929-0211.img`.
- If ButterOS won't boot: OrangeFox → flash `switch-to-butteros.zip` or `butteros-boot.img`, or dd it from adb.
- Don't factory-reset or wipe data in Android or OrangeFox. ButterOS lives at `/data/butteros/rootfs.img`.
