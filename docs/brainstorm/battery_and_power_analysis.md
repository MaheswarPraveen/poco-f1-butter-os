# ButterOS Power, Battery Charging & Thermal Diagnostics

This document details the hardware investigations, diagnostic data, and architectural solutions regarding battery life, charging rates, thermal behavior, and power policies on the **Xiaomi Poco F1 (`beryllium`)** running **ButterOS**.

---

## 🔋 1. Battery Health & Electrical Baseline

* **Battery Condition**: Replaced with a fresh OEM unit ~2 months prior to testing.
* **Fuel Gauge Reading**: **99.7% Health**, nominal 4000 mAh capacity verified via PMIC fuel-gauge registers.
* **Charge Voltage**: 3.7V nominal, 4.35V - 4.40V termination voltage.
* **Operating Temperatures**:
  - Idle (Ambient): 31°C – 34°C
  - Active Shell / Chromium Kiosk: 38°C – 42°C
  - Thermal Runaway Spike (During SLPI Crash Loop): 47°C – 51°C *(resolved)*

---

## 🔌 2. The Charging Mystery: Laptop USB vs. Wall Charger

### Phenomenon:
During development over the USB serial link (`COM5`), the phone steadily lost battery percentage even when continuously plugged in, leading to low-battery shutdowns. Conversely, on a standard 5V wall adapter, the phone charged steadily.

### Root Cause Analysis:
1. **Laptop USB Port (Mainline Charger Driver 25mA Limit)**:
   - The Linux mainline Qualcomm PMIC charger driver (`qcom_pm8998_charger` / `smb1355`) fails to receive standard USB-IF / SDP / CDP handshake tokens from certain Windows host USB controllers.
   - Lacking confirmation of host current capability, the driver enters an extreme fail-safe mode, clamping the input current limit to **25 mA**.
   - With the phone drawing ~250mA–400mA while running the Wayland compositor and shell, the battery experienced a net discharge of **-225mA to -375mA**.
2. **Dedicated 5V Wall Adapter**:
   - On a dedicated wall charger, standard BC1.2 DCP resistance is detected across D+/D-.
   - Input current successfully negotiates **1250 mA to 1350 mA**, reaching up to **+2.2 A** charging current under Android (CloverOS).

### Diagnostic Tooling Deployed:
* Created a continuous background battery logger service (`butteros-batlog.service`) recording to `/var/log/butteros-battery.csv` every 30 seconds:
  ```text
  timestamp, voltage_now, current_now, capacity, temp, status
  1970-02-17 12:35:00, 3842000, -284000, 42, 335, Discharging
  ```

---

## 💤 3. Idle Screen-Off Drain (140mA – 450mA)

### Current Behavior:
* When the screen turns off (after 60s idle via `swayidle`, or short press of the power button), the backlight is extinguished via sysfs (`bl_power = 1`).
* However, the system does **not** enter Linux `suspend-to-RAM` (`mem` / deep sleep):
  - Chromium kiosk loop remains running at 60 FPS in the background.
  - Mesa GPU context and Wayland compositor remain active.
  - Wi-Fi and CPU remain in high C-states.
* This results in an idle drain of **140 mA to 450 mA**, exhausting the battery within 8–14 hours of standby.

### Next-Phase Suspend Roadmap:
1. **Chromium Frame Throttling**:
   - Send `Page.captureScreenshot` / `Emulation.setScriptExecutionDisabled` or freeze rendering via CDP when `butteros-screen off` is invoked.
2. **True System Suspend (`systemctl suspend`)**:
   - Configure wake sources: PM8941 power key, modem ring indicator (RI), and RTC alarm.
   - Ensure the Tianma touchscreen controller (`nt36672a-ts`) safely transitions to low-power sleep mode and properly re-enumerates on resume.

---

## 🛑 4. Thermal Mitigation: Halting the SLPI Crash Loop

### The Issue:
During early bring-up, the device ran noticeably hot even while sitting idle on the table.
Kernel log investigation (`dmesg` / `stuck.log`) revealed:
```text
[ 2877.008963] butteros-poco kernel: remoteproc remoteproc2: handling crash #71 in slpi
[ 2877.009433] butteros-poco kernel: remoteproc remoteproc2: recovering slpi
[ 2917.310043] butteros-poco kernel: qcom_q6v5_pas 5c00000.remoteproc: fatal error received: err_qdi.c:456:EF:sensor_process
```
The Sensors Low Power Island (SLPI) DSP was crashing and restarting every 40 seconds because the mainline 7.1-rc1 kernel had a regression with FastRPC sensor communication. The repeated crash-recovery cycle pegged the Qualcomm PAS remote processor and drained the battery.

### The Fix:
Created `butteros-slpi-off.service` to cleanly halt the crash-looping SLPI remote processor at boot:
```bash
echo stop > /sys/class/remoteproc/remoteproc2/state
```
This dropped device idle temperature by ~8°C immediately.

---

## 🛡️ 5. Automated Protection Policy

Configured `/etc/UPower/UPower.conf` with automated threshold management:
* **Low Battery Warning (15%)**: Visual amber status pill on ButterOS shell.
* **Critical Battery Warning (5%)**: Haptic pulsation and persistent notification.
* **Action Threshold (3%)**: Triggers graceful `PowerOff` to prevent catastrophic Li-Po undervoltage.
