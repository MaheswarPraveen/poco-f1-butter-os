#!/bin/sh
# ==============================================================================
# ADD-ON: software RTC offset for the Poco F1 (SDM845, rtc-pm8xxx).
#
# The PMIC RTC keeps ticking while the phone is off, but Linux may not write it
# (Android kept the real time as an offset elsewhere). So the raw RTC reads ~1970,
# and when rtc_pm8xxx registers the kernel copies that into the system clock.
#
# Fix (same idea as postmarketOS swclock-offset):
#   save    : while the clock is known good, store  offset = system_time - rtc_time
#   restore : at boot, after the RTC registers, set system_time = rtc_time + offset
#
# Usage: butteros-rtc-offset restore|save|status
# ==============================================================================
set -u
RTC=/sys/class/rtc/rtc0
STATE_DIR=/var/lib/butteros
STATE=$STATE_DIR/rtc-offset
SANE=1767225600   # 2026-01-01 00:00 UTC; anything earlier means "clock was never set"

log() { echo "butteros-rtc-offset: $*"; }
rtc_now() { cat "$RTC/since_epoch" 2>/dev/null; }
mtime() { [ -e "$1" ] && stat -c %Y "$1" 2>/dev/null || echo 0; }

case "${1:-}" in
restore)
    # We are started by the rtc0 "add" uevent; the kernel's hctosys runs right after
    # that uevent and would overwrite whatever we set. Give it a moment to finish.
    sleep 1
    r=$(rtc_now) || r=""
    [ -n "$r" ] || { log "no $RTC, nothing to do"; exit 0; }
    if [ -e /run/systemd/timesync/synchronized ]; then
        log "NTP already synchronized, leaving clock alone"; exit 0
    fi
    now=$(date +%s)
    target=0
    if [ -s "$STATE" ]; then
        off=$(cat "$STATE")
        case "$off" in ''|*[!0-9-]*) log "corrupt $STATE, ignoring"; off="" ;; esac
        [ -n "$off" ] && target=$((r + off))
    fi
    if [ "$target" -lt "$SANE" ]; then
        # No usable offset: at least never go back before the last known-good time.
        a=$(mtime "$STATE"); b=$(mtime /var/lib/systemd/timesync/clock)
        target=$(( a > b ? a : b ))
        [ "$target" -gt "$now" ] || { log "no saved offset yet; clock left at $(date)"; exit 0; }
        log "no saved offset; advancing to last known-good time"
    fi
    date -s "@$target" >/dev/null && log "clock restored to $(date) (rtc=$r)"
    ;;
save)
    now=$(date +%s)
    if [ "$now" -lt "$SANE" ]; then log "clock not set ($(date)), not saving"; exit 0; fi
    r=$(rtc_now) || r=""
    [ -n "$r" ] || { log "no $RTC, not saving"; exit 0; }
    mkdir -p "$STATE_DIR"
    echo $((now - r)) > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE" && sync "$STATE" 2>/dev/null
    log "saved offset $((now - r))s"
    ;;
status)
    r=$(rtc_now); echo "system : $(date)"; echo "rtc    : ${r:-none} s since epoch"
    echo "offset : $(cat "$STATE" 2>/dev/null || echo none)"
    ;;
*)
    echo "usage: $0 restore|save|status" >&2; exit 2 ;;
esac
exit 0
