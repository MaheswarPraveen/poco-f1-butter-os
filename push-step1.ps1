# ==============================================================================
# ADD-ON: install the whole "phone basics" batch from OrangeFox recovery into rootfs.img.
# Files + service links go in now; packages (need network) install on the first boot via
# butteros-firstboot-setup.service (runs configs/base/butteros-base-setup.sh once, logs to
# /var/log/butteros-base-setup.log). Every step is checked; nothing reboots unless all passed.
# ==============================================================================
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$c = "debian-butteros\configs"
function Sh([string]$cmd) { $ErrorActionPreference = 'Continue'; (& adb shell $cmd 2>&1 | Out-String).Trim() }
function Fail([string]$m) { Write-Host "FAILED: $m" -ForegroundColor Red; Sh "sync; umount /mnt/butteros" | Out-Null; exit 1 }
function Push([string]$src, [string]$dst) {
    & adb push $src "/mnt/butteros$dst" | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "push $src" }
    $l = (Get-FileHash $src -Algorithm MD5).Hash.ToLower(); $r = Sh "md5sum /mnt/butteros$dst | cut -d' ' -f1"
    if ($r -ne $l) { Fail "checksum $dst" }
    Write-Host "  ok  $dst" -ForegroundColor Gray
}

if (-not (adb devices | Select-String "recovery")) { Fail "phone not in recovery" }
$m = Sh "grep -q ' /data ' /proc/mounts || mount /dev/block/sda21 /data; mkdir -p /mnt/butteros; grep -q ' /mnt/butteros ' /proc/mounts || mount -o loop /data/butteros/rootfs.img /mnt/butteros; [ -f /mnt/butteros/usr/share/butteros/shell.html ] && echo MOUNT_OK"
if ($m -notmatch 'MOUNT_OK') { Fail "mount rootfs.img: $m" }
Sh "mkdir -p /mnt/butteros/usr/local/share/butteros-setup /mnt/butteros/etc/systemd/logind.conf.d /mnt/butteros/etc/modprobe.d /mnt/butteros/var/lib/butteros" | Out-Null

Write-Host "Installing files..." -ForegroundColor Yellow
Push "debian-butteros\shell\shell.html"            "/usr/share/butteros/shell.html"
Push "$c\butteros-bridge.py"                        "/usr/local/bin/butteros-bridge.py"
Push "$c\wayland\butteros-session.sh"               "/usr/local/bin/butteros-session"
Push "$c\wayland\butteros-session.sh"               "/usr/local/bin/butteros-session.sh"
Push "$c\udev\99-pocof1-touchscreen.rules"          "/etc/udev/rules.d/99-pocof1-touchscreen.rules"
Push "$c\modprobe\butteros-no-fastrpc.conf"         "/etc/modprobe.d/butteros-no-fastrpc.conf"
Push "$c\modprobe\butteros-pd-mapper.conf"          "/etc/modprobe.d/butteros-pd-mapper.conf"
Push "$c\power\logind-butteros.conf"                "/etc/systemd/logind.conf.d/50-butteros.conf"
Push "$c\power\butteros-screen.sh"                  "/usr/local/bin/butteros-screen"
Push "$c\power\butteros-powerkey.py"                "/usr/local/bin/butteros-powerkey"
Push "$c\power\butteros-powerkey.service"           "/etc/systemd/system/butteros-powerkey.service"
Push "$c\power\butteros-slpi-off.service"           "/etc/systemd/system/butteros-slpi-off.service"
Push "$c\notify\butteros-notifyd.py"                "/usr/local/bin/butteros-notifyd"
Push "tools\cdp.py"                                 "/usr/local/bin/butteros-cdp"
Push "$c\bootanim\bootanimation.mp4"                "/usr/share/butteros/bootanimation.mp4"
Push "$c\bootanim\butteros-bootanim.sh"             "/usr/local/bin/butteros-bootanim"
Push "$c\bootanim\butteros-bootanim.service"        "/etc/systemd/system/butteros-bootanim.service"
Push "$c\bootanim\bootlogo.png"                     "/usr/share/butteros/bootlogo.png"
Push "$c\bootanim\bootlogo.bgra.gz"                 "/usr/share/butteros/bootlogo.bgra.gz"
Push "$c\wayland\butteros-gesture.sh"               "/usr/local/bin/butteros-gesture"
Push "$c\wayland\butteros-gesture.sh"               "/usr/local/share/butteros-setup/butteros-gesture.sh"
# sudoers: swayidle (user session) may run the screen script as root, nothing else
$sd = Join-Path $env:TEMP "butteros-screen.sudoers"; [IO.File]::WriteAllText($sd, "butter ALL=(root) NOPASSWD: /usr/local/bin/butteros-screen`n")
Push $sd "/etc/sudoers.d/butteros-screen"
Sh "chmod 440 /mnt/butteros/etc/sudoers.d/butteros-screen; rm -f /mnt/butteros/var/lib/butteros/base-setup.done /mnt/butteros/etc/systemd/system/multi-user.target.wants/butteros-bootanim.service; mkdir -p /mnt/butteros/etc/systemd/system/sysinit.target.wants; ln -sf /etc/systemd/system/butteros-bootanim.service /mnt/butteros/etc/systemd/system/sysinit.target.wants/butteros-bootanim.service" | Out-Null
# staged for the first-boot package install (base script copies from /tmp)
foreach ($f in "base\butteros-base-setup.sh","power\butteros-screen.sh","power\butteros-powerkey.py","power\butteros-powerkey.service","power\butteros-slpi-off.service","power\logind-butteros.conf","modprobe\butteros-pd-mapper.conf","notify\butteros-notifyd.py","bootanim\butteros-bootanim.sh","bootanim\butteros-bootanim.service","wayland\butteros-session.sh","butteros-bridge.py") {
    Push "$c\$f" "/usr/local/share/butteros-setup/$(Split-Path $f -Leaf)"
}
Push "tools\cdp.py" "/usr/local/share/butteros-setup/cdp.py"

Write-Host "Enabling services..." -ForegroundColor Yellow
$unit = @"
[Unit]
Description=ButterOS one-time package setup (needs network)
Wants=network-online.target
After=network-online.target NetworkManager-wait-online.service
ConditionPathExists=!/var/lib/butteros/base-setup.done

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'cp -f /usr/local/share/butteros-setup/* /tmp/ && cp -f /usr/share/butteros/shell.html /tmp/shell.html && bash /tmp/butteros-base-setup.sh > /var/log/butteros-base-setup.log 2>&1 && grep -q "^== DIAG" /var/log/butteros-base-setup.log && touch /var/lib/butteros/base-setup.done'
TimeoutStartSec=1800

[Install]
WantedBy=multi-user.target
"@
$tmp = Join-Path $env:TEMP "butteros-firstboot-setup.service"; [IO.File]::WriteAllText($tmp, ($unit -replace "`r", ''))
Push $tmp "/etc/systemd/system/butteros-firstboot-setup.service"
$w = "/mnt/butteros/etc/systemd/system/multi-user.target.wants"
$e = Sh "mkdir -p $w; for u in butteros-powerkey butteros-slpi-off butteros-firstboot-setup; do ln -sf /etc/systemd/system/`$u.service $w/`$u.service; done; chmod 755 /mnt/butteros/usr/local/bin/butteros-*; chmod 644 /mnt/butteros/etc/systemd/system/butteros-*.service; ls $w | grep -c butteros"
Write-Host "  enabled units in multi-user: $e" -ForegroundColor Gray

$u = Sh "sync; umount /mnt/butteros && echo UNMOUNT_OK"
if ($u -notmatch 'UNMOUNT_OK') { Fail "unmount: $u" }
Write-Host "All installed. Rebooting into ButterOS..." -ForegroundColor Green
& adb reboot
