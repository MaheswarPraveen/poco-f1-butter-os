#!/bin/sh
# ADD-ON: on-screen keyboard control, whichever keyboard is running.   butteros-kbd show|hide|toggle
# squeekboard (preferred): pops up by itself in apps via text-input; also controllable over D-Bus.
# wvkbd (fallback): USR2 = show, USR1 = hide, RTMIN = toggle.
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/1000/bus}"
if pgrep -x squeekboard >/dev/null 2>&1; then
    case "$1" in
        show) v=true ;;
        hide) v=false ;;
        *) cur=$(busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible 2>/dev/null | awk '{print $2}')
           [ "$cur" = true ] && v=false || v=true ;;
    esac
    busctl --user call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b "$v" >/dev/null 2>&1
else
    case "$1" in
        show) pkill -USR2 wvkbd-mobintl ;;
        hide) pkill -USR1 wvkbd-mobintl ;;
        *) pkill -RTMIN wvkbd-mobintl ;;
    esac
fi
exit 0
