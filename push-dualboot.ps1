# ==============================================================================
# ADD-ON: install dual boot (ButterOS <-> Clover OS) from OrangeFox recovery.
#   - stock Android boot image  -> rootfs /usr/share/butteros/boot-images/android-boot.img
#   - ButterOS boot image       -> rootfs /usr/share/butteros/boot-images/butteros-boot.img
#   - switch-to-butteros.zip    -> /data/butteros/  (flash in OrangeFox to come back)
#   - butteros-boot-switch      -> rootfs /usr/local/bin/
# Everything md5-verified. Does NOT touch the boot partition. Reboots to ButterOS at the end.
# ==============================================================================
param([string]$AndroidBoot = "C:\Games\GAMEDEV\HORIZON_SOURCES\stock_boot_raw.img")
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
function Sh([string]$c) { (& adb shell $c 2>&1 | Out-String).Trim() }
function Put([string]$src, [string]$dst) {
    & adb push $src $dst 2>&1 | Out-Null
    $ok = (Sh "md5sum '$dst' | cut -d' ' -f1") -eq (Get-FileHash $src -Algorithm MD5).Hash.ToLower()
    Write-Host ("{0,-5} {1}" -f $(if ($ok) { 'ok' } else { 'FAIL' }), $dst) -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { Sh "umount /mnt/butteros" | Out-Null; exit 1 }
}
if (-not (adb devices | Select-String "recovery")) { Write-Host "phone not in recovery" -ForegroundColor Red; exit 1 }
$m = Sh "grep -q ' /data ' /proc/mounts || mount /dev/block/sda21 /data; mkdir -p /mnt/butteros; grep -q ' /mnt/butteros ' /proc/mounts || mount -o loop /data/butteros/rootfs.img /mnt/butteros; [ -f /mnt/butteros/usr/share/butteros/shell.html ] && echo MOUNT_OK"
if ($m -notmatch 'MOUNT_OK') { Write-Host "mount failed: $m" -ForegroundColor Red; exit 1 }
Sh "mkdir -p /mnt/butteros/usr/share/butteros/boot-images" | Out-Null
Put $AndroidBoot                                          "/mnt/butteros/usr/share/butteros/boot-images/android-boot.img"
Put "debian-butteros\build\butteros-boot-quiet.img"       "/mnt/butteros/usr/share/butteros/boot-images/butteros-boot.img"
Put "debian-butteros\configs\dualboot\butteros-boot-switch.sh" "/mnt/butteros/usr/local/bin/butteros-boot-switch"
Put "debian-butteros\build\switch-to-butteros.zip"        "/data/butteros/switch-to-butteros.zip"
Put "debian-butteros\build\butteros-boot-quiet.img"       "/data/butteros/butteros-boot.img"
Sh "chmod 755 /mnt/butteros/usr/local/bin/butteros-boot-switch; sync; umount /mnt/butteros && echo UNMOUNT_OK"
Write-Host "Dual boot installed. Rebooting to ButterOS..." -ForegroundColor Green
Sh "reboot" | Out-Null
