#!/bin/sh
# Systemd suspend hook to eliminate camera focus actuator standby power drain
# Unbinds lc898217xc during s2idle sleep to save 45-80mA battery drain

case "$1/$2" in
    pre/*)
        # Unbind camera focus motor before entering sleep
        if [ -d "/sys/bus/i2c/drivers/lc898217xc/16-0072" ]; then
            echo "16-0072" > /sys/bus/i2c/drivers/lc898217xc/unbind 2>/dev/null || true
        fi
        ;;
    post/*)
        # Rebind camera focus motor upon wake
        if [ ! -d "/sys/bus/i2c/drivers/lc898217xc/16-0072" ]; then
            echo "16-0072" > /sys/bus/i2c/drivers/lc898217xc/bind 2>/dev/null || true
        fi
        ;;
esac
exit 0
