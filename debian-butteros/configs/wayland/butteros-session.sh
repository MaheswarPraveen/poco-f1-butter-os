#!/usr/bin/env bash
# ==============================================================================
# ButterOS Wayland Session Startup Script for Xiaomi Poco F1 (SDM845 / Adreno 630)
# Uses Labwc Compositor + wvkbd Virtual Keyboard + lisgd Touch Gestures
# ==============================================================================

# Export Wayland & Desktop Environment Variables
export WAYLAND_DISPLAY="wayland-0"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE="wayland"
export XDG_CURRENT_DESKTOP="ButterOS"

# Display Scale: Integer 2x for native 1080x2246 panel (enables direct zero-copy DRM scanout)
export GDK_SCALE=2
export GDK_DPI_SCALE=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_SCALE_FACTOR=2

# Mesa & GPU Acceleration (Qualcomm Adreno 630 via Mesa Turnip / Freedreno)
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_LOADER_DRIVER_OVERRIDE="freedreno"
export TU_DEBUG=gmem
export MESA_DEBUG=silent
# Disable direct scanout in wlroots scene graph to prevent KMS atomic pageflip stutter on mobile DSI panels
export WLR_SCENE_DISABLE_DIRECT_SCANOUT=1

# Audio Architecture with PipeWire
# ADD-ON: Debian already runs pipewire/pipewire-pulse/wireplumber as systemd *user* services
# (socket-activated, since PAMName=login starts user@1000). Starting them again here made
# duplicate daemons and `wpctl` hung. Only start by hand if there is no user manager.
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
if systemctl --user is-system-running >/dev/null 2>&1 || [ -S "${XDG_RUNTIME_DIR}/systemd/private" ]; then
    systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
elif which pipewire >/dev/null 2>&1; then
    pipewire &
    wireplumber &
fi

# Provision Wi-Fi and Bluetooth Hardware MAC addresses if not yet set
if [ -x "/usr/local/bin/wcn3990-mac-setup" ]; then
    /usr/local/bin/wcn3990-mac-setup || true
fi

# ADD-ON: phone-size apps. GTK4/libadwaita apps on Wayland ignore GDK_SCALE and follow the
# OUTPUT scale, so at scale 1 Photos/Music etc. rendered like tiny desktop windows. Scale the
# display itself to 3 (= 360 logical px wide, exactly what the shell used via Chromium's
# --force-device-scale-factor=3.0, which is dropped below so nothing is scaled twice).
wlr-randr --output DSI-1 --scale 3 2>/dev/null || true

# Launch Background Touchscreen Gesture Daemon (lisgd)
# 1-finger swipe up from bottom edge -> Toggles wvkbd virtual keyboard
# 2-finger swipe left/right -> Controls display brightness
if which lisgd >/dev/null 2>&1; then
    # ADD-ON (Step 1): swipe up from the bottom edge = go HOME: bring the ButterOS shell window
    # back in front of any real app (wlrctl matches it by page title) and hide the keyboard.
    # The keyboard toggle moved to a 2-finger swipe up (also: ⌨ buttons, auto-show on text fields).
    # ADD-ON: long swipe up from the bottom (past mid-screen) = RECENT APPS; short = home
    lisgd -g "1,DU,B,L,R,/usr/local/bin/butteros-gesture recents" \
          -g "1,DU,B,*,R,wlrctl toplevel focus title:'Poco F1 ButterOS Shell'; /usr/local/bin/butteros-kbd hide" \
          -g "2,DU,*,*,R,/usr/local/bin/butteros-kbd toggle" \
          -g "1,LR,L,*,R,/usr/local/bin/butteros-gesture back" \
          -g "1,RL,R,*,R,/usr/local/bin/butteros-gesture back" \
          -g "1,UD,T,*,R,/usr/local/bin/butteros-gesture notif" \
          -g "1,DU,BL,*,R,/usr/local/bin/butteros-gesture arcleft" \
          -g "1,DU,BR,*,R,/usr/local/bin/butteros-gesture arcright" \
          -g "2,RL,*,*,R,brightnessctl set 10%-" \
          -g "2,LR,*,*,R,brightnessctl set +10%" &
fi

# ADD-ON: screen off after 60 s without touch (phone-style). Wake with a short power-key press
# (butteros-powerkey). Touch is inhibited while off so pocket touches do nothing.
if which swayidle >/dev/null 2>&1 && [ -x /usr/local/bin/butteros-screen ]; then
    swayidle -w timeout 60 'sudo -n /usr/local/bin/butteros-screen off' &
fi

# ADD-ON: squeekboard = phone keyboard that pops up by itself when a text field in an app
# (or the shell, via Chromium's Wayland IME) gets focus. wvkbd stays as the fallback.
if which squeekboard >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true 2>/dev/null || true
    squeekboard &
elif which wvkbd-mobintl >/dev/null 2>&1; then
    # Launch Lightweight On-Screen Virtual Keyboard in background (<8MB RAM)
    wvkbd-mobintl --hidden -L 280 --bg 0d0c0a --fg deb056 &
fi

# ADD-ON (security): per-boot secret for the command bridge. Only the shell page receives it
# (URL fragment below); web pages in Chromium can't, so they can no longer run commands.
export BUTTEROS_BRIDGE_TOKEN="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
( umask 077; printf '%s' "$BUTTEROS_BRIDGE_TOKEN" > "${XDG_RUNTIME_DIR}/butteros-bridge.token" )

# Launch Native Application Execution Bridge (Port 9090)
if [ -f "/usr/local/bin/butteros-bridge.py" ]; then
    python3 /usr/local/bin/butteros-bridge.py &
fi

# ADD-ON: freedesktop notification service so apps (clocks, calls, SMS...) can post alerts
if [ -f /usr/local/bin/butteros-notifyd ]; then
    python3 /usr/local/bin/butteros-notifyd &
fi

# ADD-ON: no keyring password prompts. Auto-login never types a password, so the GNOME keyring
# (used by Chatty/Calls/Contacts) stayed locked and popped an unlock dialog at every boot.
# One-time: drop the old password-protected keyring; then create/unlock one with an EMPTY password.
if which gnome-keyring-daemon >/dev/null 2>&1; then
    KR="$HOME/.local/share/keyrings"
    if [ ! -f "$KR/.butteros-nopass" ]; then
        mkdir -p "$KR"; rm -f "$KR"/*.keyring; printf 'login' > "$KR/default"; : > "$KR/.butteros-nopass"
    fi
    printf '' | gnome-keyring-daemon --replace --unlock --components=secrets,pkcs11 >/dev/null 2>&1 &
fi

# ADD-ON: GTK/libadwaita apps follow the dark shell
gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true

# Launch ButterOS Kiosk Shell under Labwc
SHELL_PATH="/usr/share/butteros/shell.html"

# ADD-ON: GPU. Vulkan-through-ANGLE is experimental on Linux/ARM and its GPU process kept
# crashing; use ANGLE on GLES (freedreno). If Chromium dies 3x within 20 s of starting,
# fall back to the previous Vulkan flag set automatically.
GPU_FLAGS_GLES="--ignore-gpu-blocklist --use-gl=angle --use-angle=gles"
GPU_FLAGS_OLD="--enable-features=UseOzonePlatform,Vulkan,VulkanFromANGLE,DefaultANGLEVulkan --ignore-gpu-blocklist --use-gl=angle --use-angle=vulkan"
QUICK_FAILS=0

# ADD-ON: watchdog - if the shell page stops answering (frozen JS), restart it
if [ -x /usr/local/bin/butteros-cdp ]; then
    ( sleep 90; misses=0
      while true; do
          if timeout 8 /usr/local/bin/butteros-cdp eval 1 >/dev/null 2>&1; then misses=0; else misses=$((misses + 1)); fi
          if [ "$misses" -ge 3 ]; then pkill -f -- '--app=file:///usr/share/butteros/shell.html'; misses=0; sleep 60; fi
          sleep 20
      done ) &
fi

# Chromium Wayland Launch with Hardware Compositing & Crash Supervision Loop
if which chromium >/dev/null 2>&1; then
    while true; do
        if [ "$QUICK_FAILS" -ge 3 ]; then GPU_FLAGS="$GPU_FLAGS_OLD"; else GPU_FLAGS="$GPU_FLAGS_GLES"; fi
        STARTED=$(date +%s)
        # shellcheck disable=SC2086
        chromium \
            --ozone-platform=wayland \
            $GPU_FLAGS \
            --kiosk \
            --noerrdialogs \
            --disable-infobars \
            --disable-session-crashed-bubble \
            --check-for-update-interval=31536000 \
            --touch-events=enabled \
            --disable-touch-adjustment \
            --blink-settings=primaryPointerType=2,availablePointerTypes=2,primaryHoverType=1,availableHoverTypes=1 \
            --disable-pinch \
            --disable-dev-shm-usage \
            --disable-smooth-scrolling \
            --enable-wayland-ime --wayland-text-input-version=3 \
            --high-dpi-support=1 \
            --force-dark-mode \
            --remote-debugging-port=9222 \
            --remote-debugging-address=127.0.0.1 \
            --app="file://${SHELL_PATH}#t=${BUTTEROS_BRIDGE_TOKEN}"
        # ADD-ON: count quick exits (crash at startup) for the GPU fallback above
        if [ $(( $(date +%s) - STARTED )) -lt 20 ]; then QUICK_FAILS=$((QUICK_FAILS + 1)); else QUICK_FAILS=0; fi
        sleep 1
    done
elif which epiphany >/dev/null 2>&1; then
    exec epiphany --application-mode "file://${SHELL_PATH}"
fi
