#!/bin/sh
# ADD-ON: system gestures/panels that work on top of real apps (called by lisgd, which reads the
# touchscreen directly, and by butteros-powerkey for the volume OSD).
#   butteros-gesture back|notif|arcleft|arcright|recents|volume <pct> <muted>
# The shell is an ordinary window, so an app in front hides anything it draws. Over an app we:
#   1. snapshot the screen (grim) -> 2. raise the shell, which shows the snapshot blurred as its
#   backdrop and opens the panel on top -> 3. when the panel closes, the shell refocuses the app.
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
SHELL_TITLE='Poco F1 ButterOS Shell'
UNDER="$XDG_RUNTIME_DIR/butteros-under.png"
APP_IDS="org.gnome.Calculator org.gnome.clocks org.gnome.Nautilus org.gnome.Console org.gnome.Loupe org.gnome.TextEditor io.bassi.Amberol sm.puri.Chatty org.gnome.Calls org.gnome.Contacts org.postmarketos.Megapixels chromium"

shell_active() { wlrctl toplevel find "title:$SHELL_TITLE" state:active >/dev/null 2>&1; }
cdp() { timeout 5 /usr/local/bin/butteros-cdp eval "$1" >/dev/null 2>&1; }
active_app() {
    for id in $APP_IDS; do
        wlrctl toplevel find "app_id:$id" state:active >/dev/null 2>&1 && { echo "$id"; return; }
    done
}

# show a shell panel; over an app, snapshot it first so the panel appears ON the app
panel() {   # $1 = JS panel name for window.__overApp
    if shell_active; then
        cdp "window.__overApp && window.__overApp('', '$1')"
        return
    fi
    app=$(active_app)
    grim -s 0.34 -t png -l 1 "$UNDER.tmp" 2>/dev/null && mv -f "$UNDER.tmp" "$UNDER"
    wlrctl toplevel focus "title:$SHELL_TITLE" >/dev/null 2>&1
    cdp "window.__overApp && window.__overApp('$app', '$1')"
}

case "$1" in
    recents)
        wlrctl toplevel focus "title:$SHELL_TITLE" >/dev/null 2>&1
        cdp 'window.__openRecents && window.__openRecents()' ;;
    back)
        shell_active && exit 0
        wtype -M alt -k Left -m alt 2>/dev/null ;;          # libadwaita / GTK "go back"
    notif)
        shell_active && exit 0      # the shell handles its own top pull
        panel notif ;;
    arcleft)
        shell_active && exit 0
        panel arcleft ;;
    arcright)
        shell_active && exit 0
        panel arcright ;;
    volume)
        if shell_active; then
            cdp "window.__showVolume && window.__showVolume(${2:-0}, ${3:-false})"
        else
            panel "volume:${2:-0}:${3:-false}"
        fi ;;
esac
exit 0
