#!/bin/bash
# ==============================================================================
# ADD-ON: ButterOS base layer for the Poco F1 (run once on the phone, as root, online).
# From the research pass (pmOS / Mobian / Debian trixie):
#   - qcom-phone-utils: bootmac (stable BT + Wi-Fi MAC -> Bluetooth controller becomes
#     usable), q6voiced (call audio), qcom-modem-setup (SIM app selection), qcom WP tweak
#   - pipewire-pulse / pipewire-alsa / rtkit: proper user-service audio (no hand-started dupes)
#   - callaudiod: call audio routing;  libnotify-bin: notify-send for testing
#   - mesa-vulkan-drivers + libgl1-mesa-dri + mesa-utils: real Adreno GL/Vulkan + eglinfo
#   - pd-mapper softdep: avoids the DSP-start race behind the early-boot reset
# Prints diagnostics at the end; changes nothing in the boot image / initramfs.
# ==============================================================================
set -u
log() { echo "== $*"; }

log "packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    qcom-phone-utils callaudiod pipewire-pulse pipewire-alsa rtkit libnotify-bin \
    mesa-vulkan-drivers libgl1-mesa-dri mesa-utils alsa-utils bluez-tools swayidle 2>&1 | tail -3

log "power key + screen off + stop crash-looping SLPI"
install -m 0755 /tmp/butteros-screen.sh /usr/local/bin/butteros-screen
install -m 0755 /tmp/butteros-powerkey.py /usr/local/bin/butteros-powerkey
install -m 0644 /tmp/butteros-powerkey.service /tmp/butteros-slpi-off.service /etc/systemd/system/
mkdir -p /etc/systemd/logind.conf.d && install -m 0644 /tmp/logind-butteros.conf /etc/systemd/logind.conf.d/50-butteros.conf
systemctl daemon-reload
systemctl enable butteros-powerkey.service butteros-slpi-off.service 2>&1 | tail -2

log "phone basics: notifications, screenshots, boot animation, watchdog tool"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3-dbus python3-gi grim mpv wlsunset wf-recorder wlr-randr wtype firmware-qcom-soc squeekboard librsvg2-common gstreamer1.0-plugins-good gstreamer1.0-pipewire 2>&1 | tail -2
[ -f /tmp/butteros-kbd.sh ] && install -m 0755 /tmp/butteros-kbd.sh /usr/local/bin/butteros-kbd
[ -f /tmp/butteros-gesture.sh ] && install -m 0755 /tmp/butteros-gesture.sh /usr/local/bin/butteros-gesture
# screen on/off is called by the user session (swayidle) through sudo; keep that instant
echo 'butter ALL=(root) NOPASSWD: /usr/local/bin/butteros-screen' > /etc/sudoers.d/butteros-screen && chmod 440 /etc/sudoers.d/butteros-screen
[ -f /tmp/butteros-notifyd.py ] && install -m 0755 /tmp/butteros-notifyd.py /usr/local/bin/butteros-notifyd
[ -f /tmp/cdp.py ] && install -m 0755 /tmp/cdp.py /usr/local/bin/butteros-cdp
if [ -f /tmp/bootanimation.mp4 ]; then
    install -m 0644 /tmp/bootanimation.mp4 /usr/share/butteros/bootanimation.mp4
    install -m 0755 /tmp/butteros-bootanim.sh /usr/local/bin/butteros-bootanim
    install -m 0644 /tmp/butteros-bootanim.service /etc/systemd/system/
    systemctl daemon-reload; systemctl enable butteros-bootanim.service 2>&1 | tail -1
fi

log "battery policy: warn 15%, critical 5%, safe power-off at 3%"
UP=/etc/UPower/UPower.conf
if [ -f "$UP" ]; then
    sed -i -E 's/^#?UsePercentageForPolicy=.*/UsePercentageForPolicy=true/; s/^#?PercentageLow=.*/PercentageLow=15/;
               s/^#?PercentageCritical=.*/PercentageCritical=5/; s/^#?PercentageAction=.*/PercentageAction=3/;
               s/^#?CriticalPowerAction=.*/CriticalPowerAction=PowerOff/' "$UP"
    grep -E '^(UsePercentage|Percentage|CriticalPowerAction)' "$UP"
    systemctl enable upower 2>/dev/null
fi

log "pd-mapper load order"
install -m 0644 /tmp/butteros-pd-mapper.conf /etc/modprobe.d/butteros-pd-mapper.conf && echo ok

log "groups"
usermod -aG video,render,audio,input butter && id butter

log "services"
systemctl enable q6voiced.service 2>&1 | tail -1
systemctl enable qcom-modem-setup.service 2>&1 | tail -1
systemctl list-unit-files 'bootmac*' 'q6voiced*' 'qcom-modem*' --no-pager --plain | head -8
ls /usr/lib/udev/rules.d/ /lib/udev/rules.d/ 2>/dev/null | grep -i bootmac

log "shell + bridge + session (token security, GPU flags, notifications, watchdog)"
[ -f /tmp/butteros-bridge.py ] && install -m 0755 /tmp/butteros-bridge.py /usr/local/bin/butteros-bridge.py
if [ -f /tmp/butteros-session.sh ] && bash -n /tmp/butteros-session.sh; then
    install -m 0755 /tmp/butteros-session.sh /usr/local/bin/butteros-session
    install -m 0755 /tmp/butteros-session.sh /usr/local/bin/butteros-session.sh
fi
if [ -f /tmp/shell.html ]; then
    cp -f /usr/share/butteros/shell.html /usr/share/butteros/shell.html.prev
    install -m 0644 /tmp/shell.html /usr/share/butteros/shell.html
fi

log "user audio services"
sudo -u butter XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>&1 | tail -2

log "DIAG gpu firmware / driver"
dmesg | grep -iE 'a6xx|adreno|gmu|zap|a630|msm_dpu|\[drm\]' | tail -15
ls -l /usr/lib/firmware/qcom/a630_sqe.fw /usr/lib/firmware/qcom/a630_gmu.bin /usr/lib/firmware/qcom/sdm845/Xiaomi/beryllium/a630_zap.mbn 2>&1
ls -l /dev/dri/

log "DIAG audio"
aplay -l 2>&1 | head -8
dmesg | grep -iE 'q6|apr|asoc|tas25' | tail -8

log "DIAG bluetooth"
timeout 5 btmgmt info < /dev/null 2>&1 | head -8   # btmgmt waits for input forever without this
echo DONE
