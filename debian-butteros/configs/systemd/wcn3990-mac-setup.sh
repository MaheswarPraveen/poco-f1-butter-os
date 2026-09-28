#!/bin/sh
# ==============================================================================
# Qualcomm WCN3990 Wi-Fi & Bluetooth MAC Address Provisioning for Poco F1
# Solves the missing eFuse hardware MAC address trap on SDM845
# ==============================================================================
set -e

PERSIST_DEV="/dev/disk/by-partlabel/persist"
MOUNT_DIR="/run/persist_mnt"

if [ -b "$PERSIST_DEV" ]; then
    mkdir -p "$MOUNT_DIR"
    mount -o ro "$PERSIST_DEV" "$MOUNT_DIR" || true

    if [ -f "$MOUNT_DIR/wlan_mac.bin" ]; then
        # 1. Provision Wi-Fi MAC Address
        RAW_WIFI_MAC=$(grep -i '^Intf0MacAddress=' "$MOUNT_DIR/wlan_mac.bin" | head -1 | cut -d'=' -f2 | tr -d '\r\n')
        if [ -n "$RAW_WIFI_MAC" ]; then
            FORMATTED_WIFI_MAC=$(echo "$RAW_WIFI_MAC" | sed -e 's/..\B/&:/g')
            if ip link show wlan0 >/dev/null 2>&1; then
                ip link set dev wlan0 address "$FORMATTED_WIFI_MAC" || true
            fi

            # 2. Provision Bluetooth MAC Address (Derived from base Wi-Fi MAC + 1)
            # Necessary because WCN3990 lacks a fused Bluetooth MAC in eFuse/OTP
            BT_INT=$(( 0x$(echo "$RAW_WIFI_MAC" | tail -c 3) + 1 ))
            BT_TAIL=$(printf "%02X" $(( BT_INT % 256 )))
            RAW_BT_MAC="$(echo "$RAW_WIFI_MAC" | cut -c 1-10)${BT_TAIL}"
            FORMATTED_BT_MAC=$(echo "$RAW_BT_MAC" | sed -e 's/..\B/&:/g')
            
            if which btmgmt >/dev/null 2>&1; then
                btmgmt --index 0 public-addr "$FORMATTED_BT_MAC" || true
            fi
        fi
    fi

    umount "$MOUNT_DIR" 2>/dev/null || true
    rmdir "$MOUNT_DIR" 2>/dev/null || true
fi

exit 0
