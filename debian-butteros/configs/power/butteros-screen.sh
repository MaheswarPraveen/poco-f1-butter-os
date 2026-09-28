#!/bin/sh
# ADD-ON: phone screen on/off.  butteros-screen on|off|toggle|state
# Off = BACKLIGHT off (bl_power) + touchscreen inhibited. The display pipeline itself is left
# running: powering the DSI output down/up via wlr-randr stalled the msm driver on this kernel
# (USB console stopped answering, keys lagged). Direct sysfs writes as root = instant.
# As a non-root caller (swayidle), it re-runs itself through sudo once.
STATE=/run/butteros-screen-off
BL=/sys/class/backlight/backlight

if [ "$(id -u)" != 0 ]; then exec sudo -n "$0" "$@"; fi

# Touch while off: butteros-powerkey GRABS the touchscreen (apps get nothing) and turns a
# double-tap into "screen on". (Was: input inhibit = no tap-to-wake possible.)
# Decisions use the REAL backlight state, not just the marker file - a stale marker made
# the power key need two presses to wake.
is_off() { [ "$(cat "$BL/bl_power" 2>/dev/null)" != 0 ] || [ "$(cat "$BL/brightness" 2>/dev/null)" = 0 ]; }

off() {
    is_off && { : > "$STATE"; return; }
    cat "$BL/brightness" > /run/butteros-screen-brightness 2>/dev/null
    echo 4 > "$BL/bl_power" 2>/dev/null || echo 0 > "$BL/brightness"
    pkill -USR1 wvkbd-mobintl 2>/dev/null
    : > "$STATE"
}
on() {
    is_off || { rm -f "$STATE"; return; }
    echo 0 > "$BL/bl_power" 2>/dev/null
    b=$(cat /run/butteros-screen-brightness 2>/dev/null); [ -n "$b" ] && [ "$b" -gt 0 ] && echo "$b" > "$BL/brightness"
    rm -f "$STATE"
    # bump the wake counter -> the shell shows the lock screen (bridge /state)
    n=$(cat /run/butteros-wake 2>/dev/null || echo 0); echo $((n + 1)) > /run/butteros-wake
}

case "${1:-toggle}" in
    off) off ;;
    on) on ;;
    toggle) if is_off; then on; else off; fi ;;
    state) is_off && echo off || echo on ;;
esac
