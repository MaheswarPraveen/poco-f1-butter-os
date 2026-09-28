# ==============================================================================
# ADD-ON: push the ButterOS hardware payload (kernel modules + firmware + Qualcomm
# helper packages + first-boot setup service) into /data/butteros/rootfs.img from
# OrangeFox recovery. Every step is checked; nothing is reported "done" unless it is.
#
# Prereq: in WSL, from debian-butteros\:   bash hw/fetch_hw_payload.sh
# Run from the project root:                 .\push-hw.ps1
# ==============================================================================
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$payload = "debian-butteros\build\butteros-hw-payload.tar.gz"
if (-not (Test-Path $payload)) { throw "Missing $payload. Run 'bash hw/fetch_hw_payload.sh' in WSL (inside debian-butteros) first." }
$payloadMB = [math]::Ceiling((Get-Item $payload).Length / 1MB)

function AdbSh([string]$cmd) {
    # local 'Continue': Windows PowerShell 5.1 turns native stderr into terminating errors under 'Stop'
    $ErrorActionPreference = 'Continue'
    $out = (& adb shell $cmd 2>&1 | Out-String).Trim()
    return $out
}
function Fail([string]$msg) {
    Write-Host "FAILED: $msg" -ForegroundColor Red
    AdbSh "sync; umount /mnt/butteros 2>/dev/null" | Out-Null
    Write-Host "rootfs.img unmounted; phone left in recovery. Nothing was rebooted." -ForegroundColor Yellow
    exit 1
}

Write-Host "Waiting for Poco F1 in OrangeFox Recovery (Hold Power + Vol Up)..." -ForegroundColor Cyan
while (-not (adb devices | Select-String "recovery")) { Start-Sleep -Seconds 2 }
Write-Host "Device detected in recovery." -ForegroundColor Green

Write-Host "Mounting ButterOS rootfs.img..." -ForegroundColor Yellow
$m = AdbSh "grep -q ' /data ' /proc/mounts || mount /dev/block/sda21 /data; mkdir -p /mnt/butteros; grep -q ' /mnt/butteros ' /proc/mounts || mount -o loop /data/butteros/rootfs.img /mnt/butteros; if [ -f /mnt/butteros/etc/os-release ] && [ -d /mnt/butteros/usr/share/butteros ]; then echo MOUNT_VERIFIED; else echo MOUNT_FAILED; fi"
if ($m -notmatch 'MOUNT_VERIFIED') { Fail "rootfs.img is not mounted correctly:`n$m" }

$free = AdbSh "df -k /mnt/butteros | tail -n 1 | awk '{print `$4}'"
$freeMB = [math]::Floor([double]($free -replace '[^0-9]', '') / 1024)
$needMB = $payloadMB * 4
Write-Host "Free in rootfs.img: $freeMB MB (need ~$needMB MB)" -ForegroundColor Gray
if ($freeMB -lt $needMB) { Fail "not enough free space in rootfs.img" }

Write-Host "Pushing hardware payload ($payloadMB MB)..." -ForegroundColor Yellow
& adb push $payload /mnt/butteros/var/tmp/butteros-hw-payload.tar.gz
if ($LASTEXITCODE -ne 0) { Fail "adb push failed" }

Write-Host "Extracting into rootfs..." -ForegroundColor Yellow
$x = AdbSh "cd /mnt/butteros && tar -xzpf var/tmp/butteros-hw-payload.tar.gz && echo EXTRACT_OK; rm -f /mnt/butteros/var/tmp/butteros-hw-payload.tar.gz"
if ($x -notmatch 'EXTRACT_OK') { Fail "extraction failed:`n$x" }

Write-Host "Enabling first-boot hardware setup..." -ForegroundColor Yellow
$e = AdbSh "mkdir -p /mnt/butteros/etc/systemd/system/multi-user.target.wants && ln -sf /etc/systemd/system/butteros-hwsetup.service /mnt/butteros/etc/systemd/system/multi-user.target.wants/butteros-hwsetup.service && rm -f /mnt/butteros/var/lib/butteros/hwsetup.done && chmod 755 /mnt/butteros/usr/local/bin/butteros-hwsetup && echo ENABLE_OK"
if ($e -notmatch 'ENABLE_OK') { Fail "could not enable butteros-hwsetup:`n$e" }

Write-Host "Verifying..." -ForegroundColor Yellow
$v = AdbSh ". /mnt/butteros/var/lib/butteros/hw-info; echo KVER=`$KVER; echo MODULES=`$(find /mnt/butteros/usr/lib/modules/`$KVER -name '*.ko*' | wc -l); echo FIRMWARE=`$(find /mnt/butteros/usr/lib/firmware -type f | wc -l); echo DEBS=`$(ls /mnt/butteros/var/lib/butteros/hw-debs | wc -l)"
Write-Host $v -ForegroundColor Gray
if ($v -notmatch 'MODULES=[1-9]' -or $v -notmatch 'FIRMWARE=[1-9]') { Fail "payload not present after extraction" }

Write-Host "Syncing, unmounting, rebooting..." -ForegroundColor Yellow
$u = AdbSh "sync; umount /mnt/butteros && echo UNMOUNT_OK"
if ($u -notmatch 'UNMOUNT_OK') { Fail "unmount failed:`n$u" }
& adb reboot
Write-Host "Done. Once ButterOS has booted (give it ~1 min), run .\phone-run.ps1 - it saves a hardware report to phone.log" -ForegroundColor Green
