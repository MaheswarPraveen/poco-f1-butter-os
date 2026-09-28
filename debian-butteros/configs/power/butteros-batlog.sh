#!/bin/sh
# ADD-ON: battery logger - one line every 30 s to /var/log/butteros-battery.csv (kept across
# reboots/shutdowns, trimmed to ~2 days). Used to diagnose charging / unexpected shutdowns:
# time, uptime, %, voltage (mV), battery current (mA, + = charging), temp (C), status,
# charger type, charger input current (mA), screen state.
LOG=/var/log/butteros-battery.csv
B=/sys/class/power_supply/qcom-battery
C=/sys/class/power_supply/pmi8998-charger
[ -f "$LOG" ] || echo "time,uptime_s,percent,voltage_mV,battery_mA,temp_C,status,charger,charger_in_mA,screen" > "$LOG"
echo "# boot $(date '+%F %T')" >> "$LOG"
while true; do
    ut=$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)
    cap=$(cat $B/capacity 2>/dev/null); v=$(( $(cat $B/voltage_now 2>/dev/null || echo 0) / 1000 ))
    i=$(( $(cat $B/current_now 2>/dev/null || echo 0) / 1000 )); t=$(( $(cat $B/temp 2>/dev/null || echo 0) / 10 ))
    st=$(cat $B/status 2>/dev/null); ct=$(sed -n 's/.*\[\(.*\)\].*/\1/p' $C/usb_type 2>/dev/null)
    ci=$(( $(cat $C/current_now 2>/dev/null || echo 0) / 1000 ))
    [ "$(cat /sys/class/backlight/backlight/bl_power 2>/dev/null)" = 0 ] && scr=on || scr=off
    echo "$(date '+%F %T'),$ut,$cap,$v,$i,$t,$st,$ct,$ci,$scr" >> "$LOG"
    # keep ~2 days (5760 lines)
    [ $(wc -l < "$LOG") -gt 6000 ] && { tail -n 5760 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
    sync "$LOG" 2>/dev/null
    sleep 30
done
