Write-Host "Waiting for Poco F1 in OrangeFox Recovery (Hold Power + Vol Up)..." -ForegroundColor Cyan
while ($true) {
    $dev = adb devices | Select-String "recovery"
    if ($dev) {
        Write-Host "Device detected in recovery!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 2
}

Write-Host "Mounting ButterOS rootfs loop image..." -ForegroundColor Yellow
adb shell "mount /dev/block/sda21 /data 2>/dev/null; mkdir -p /mnt/butteros; mount -o loop /data/butteros/rootfs.img /mnt/butteros 2>/dev/null; echo MOUNT_OK"

Write-Host "Pushing upgraded shell.html..." -ForegroundColor Yellow
adb push "debian-butteros\shell\shell.html" /mnt/butteros/usr/share/butteros/shell.html

Write-Host "Pushing upgraded butteros-bridge.py..." -ForegroundColor Yellow
adb push "debian-butteros\configs\butteros-bridge.py" /mnt/butteros/usr/local/bin/butteros-bridge.py

Write-Host "Pushing upgraded butteros-session.sh (Scale 3.0)..." -ForegroundColor Yellow
adb push "debian-butteros\configs\wayland\butteros-session.sh" /mnt/butteros/usr/local/bin/butteros-session
adb push "debian-butteros\configs\wayland\butteros-session.sh" /mnt/butteros/usr/local/bin/butteros-session.sh

Write-Host "Pushing Labwc rc.xml (mouseEmulation=no - restoring raw wl_touch)..." -ForegroundColor Yellow
adb shell "mkdir -p /mnt/butteros/home/butter/.config/labwc /mnt/butteros/etc/xdg/labwc"
adb push "debian-butteros\configs\wayland\rc.xml" /mnt/butteros/home/butter/.config/labwc/rc.xml
adb push "debian-butteros\configs\wayland\rc.xml" /mnt/butteros/etc/xdg/labwc/rc.xml

Write-Host "Pushing ButterOS Shell Service & Getty Autologin Override..." -ForegroundColor Yellow
adb push "debian-butteros\configs\systemd\butteros-shell.service" /mnt/butteros/etc/systemd/system/butteros-shell.service
adb shell "mkdir -p /mnt/butteros/etc/tmpfiles.d /mnt/butteros/etc/systemd/system/graphical.target.wants /mnt/butteros/etc/systemd/system/multi-user.target.wants /mnt/butteros/etc/systemd/system/getty@tty1.service.d; ln -sf /etc/systemd/system/butteros-shell.service /mnt/butteros/etc/systemd/system/graphical.target.wants/butteros-shell.service; ln -sf /etc/systemd/system/butteros-shell.service /mnt/butteros/etc/systemd/system/multi-user.target.wants/butteros-shell.service; ln -sf /lib/systemd/system/graphical.target /mnt/butteros/etc/systemd/system/default.target"
adb push "debian-butteros\configs\systemd\butteros-cpufreq.conf" /mnt/butteros/etc/tmpfiles.d/butteros-cpufreq.conf
adb push "debian-butteros\configs\systemd\getty-autologin.conf" /mnt/butteros/etc/systemd/system/getty@tty1.service.d/override.conf

# ADD-ON: software RTC offset (SDM845 RTC is read-only; without this the clock resets to 1970)
Write-Host "Pushing RTC offset clock fix..." -ForegroundColor Yellow
adb push "debian-butteros\configs\time\butteros-rtc-offset.sh" /mnt/butteros/usr/local/bin/butteros-rtc-offset
foreach ($u in 'butteros-rtc-offset.service','butteros-rtc-offset-save.service','butteros-rtc-offset-save.timer','butteros-rtc-offset-save.path') {
    adb push "debian-butteros\configs\time\$u" /mnt/butteros/etc/systemd/system/$u
}
adb push "debian-butteros\configs\time\90-butteros-rtc.rules" /mnt/butteros/etc/udev/rules.d/90-butteros-rtc.rules
adb shell "mkdir -p /mnt/butteros/etc/systemd/system/timers.target.wants; ln -sf /etc/systemd/system/butteros-rtc-offset-save.timer /mnt/butteros/etc/systemd/system/timers.target.wants/; ln -sf /etc/systemd/system/butteros-rtc-offset-save.path /mnt/butteros/etc/systemd/system/multi-user.target.wants/; chmod 755 /mnt/butteros/usr/local/bin/butteros-rtc-offset; chmod 644 /mnt/butteros/etc/systemd/system/butteros-rtc-offset* /mnt/butteros/etc/udev/rules.d/90-butteros-rtc.rules"

# ADD-ON: stop the SLPI fastrpc probe loop (burned a full core + heat)
adb shell "mkdir -p /mnt/butteros/etc/modprobe.d"
adb push "debian-butteros\configs\modprobe\butteros-no-fastrpc.conf" /mnt/butteros/etc/modprobe.d/butteros-no-fastrpc.conf
# ADD-ON: adbd gadget fights the USB serial console for the port and spins at 300% CPU - keep it off
adb shell "rm -f /mnt/butteros/etc/systemd/system/sysinit.target.wants/butteros-gadget.service"

Write-Host "Syncing filesystem and unmounting..." -ForegroundColor Yellow
adb shell "chmod 755 /mnt/butteros/usr/local/bin/butteros-bridge.py /mnt/butteros/usr/local/bin/butteros-session /mnt/butteros/usr/local/bin/butteros-session.sh; chmod 644 /mnt/butteros/home/butter/.config/labwc/rc.xml /mnt/butteros/etc/xdg/labwc/rc.xml /mnt/butteros/etc/systemd/system/butteros-shell.service /mnt/butteros/etc/tmpfiles.d/butteros-cpufreq.conf /mnt/butteros/etc/systemd/system/getty@tty1.service.d/override.conf 2>/dev/null; chown -R 1000:1000 /mnt/butteros/home/butter/.config 2>/dev/null; sync; umount /mnt/butteros; echo UNMOUNT_DONE; reboot"

Write-Host "ButterOS updated and phone rebooting! All done!" -ForegroundColor Green
