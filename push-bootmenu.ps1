# ==============================================================================
# ADD-ON: install the ButterOS boot menu from OrangeFox recovery (md5-verified), then reboot.
# ==============================================================================
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
$c = "debian-butteros\configs"
Sh "mkdir -p /mnt/butteros/usr/share/butteros/bootmenu /mnt/butteros/etc/systemd/system/sysinit.target.wants" | Out-Null
Get-ChildItem "$c\bootmenu\frames\*.bgra.gz" | ForEach-Object { Put $_.FullName "/mnt/butteros/usr/share/butteros/bootmenu/$($_.Name)" }
Put "$c\bootmenu\butteros-bootmenu.py"        "/mnt/butteros/usr/local/bin/butteros-bootmenu"
Put "$c\bootmenu\butteros-bootmenu.service"   "/mnt/butteros/etc/systemd/system/butteros-bootmenu.service"
Put "$c\bootanim\butteros-bootanim.service"   "/mnt/butteros/etc/systemd/system/butteros-bootanim.service"
Sh "chmod 755 /mnt/butteros/usr/local/bin/butteros-bootmenu; ln -sf /etc/systemd/system/butteros-bootmenu.service /mnt/butteros/etc/systemd/system/sysinit.target.wants/butteros-bootmenu.service; sync; umount /mnt/butteros && echo UNMOUNT_OK"
Write-Host "Boot menu installed. Rebooting..." -ForegroundColor Green
Sh "reboot" | Out-Null
