# Hardware Debug & Run Logs Archive

This directory stores serial console command output captures from live on-device testing via `phone-run.ps1` and `phone-cdp.ps1` over Windows `COM5` (ButterOS USB Serial Console).

Key logs of note:
- `phone.log`: First-boot hardware bring-up and systemd unit verification.
- `touch.log`: NT36672A touchscreen event probing and udev classification diagnosis.
- `wifi.log` & `wifi-diag.log`: WCN3990 Wi-Fi firmware loading and connection logs.
- `tone.log` & `ucm.log`: ALSA UCM2 and TAS2559 smart audio amplifier configuration diagnostics.
- `native1.log`, `native2.log`, `native3.log`: GTK4 / Wayland / DRM render node permission testing (`GSK_RENDERER=cairo` vs `ngl`).
- `stuck.log` & `off.log`: Kernel shutdown, watchdog timeouts, and powerkey state machine analysis.
