# ==============================================================================
# ADD-ON: fast UI deploy - no recovery, no reboot.
# Streams debian-butteros\shell\shell.html to the running phone over the ButterOS USB
# serial console, verifies its md5, keeps a backup of the old one, reloads the UI.
# Reload = kill only the Chromium showing shell.html; butteros-session's loop relaunches it.
# NEVER `systemctl restart butteros-shell`: it kills labwc only, the old session (Chromium,
# bridge, respawn loop) survives in its logind scope -> two shells + OOM. Reboot instead.
#
#   .\deploy-shell.ps1              # auto-detect the port
#   .\deploy-shell.ps1 -Port COM5
#   .\deploy-shell.ps1 -Rollback    # put the previous shell.html back
# ==============================================================================
param([string]$Port = "", [switch]$Rollback)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $Port) {
    $ports = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'USB Serial Device \((COM\d+)\)' } |
               ForEach-Object { if ($_.Name -match '\((COM\d+)\)') { $Matches[1] } })
    if ($ports.Count -ne 1) { throw "Need exactly one USB serial port, found: $($ports -join ', '). Use -Port COMx." }
    $Port = $ports[0]
}
$dest = '/usr/share/butteros/shell.html'

if ($Rollback) {
    & .\phone-run.ps1 -Port $Port -Out deploy.log "sudo cp -f $dest.prev $dest && md5sum $dest && { pkill -f -- '--app=file:///usr/share/butteros/shell.html'; echo ROLLBACK_OK; }"
    Get-Content deploy.log; exit
}

$src = "debian-butteros\shell\shell.html"
$bytes = [IO.File]::ReadAllBytes((Resolve-Path $src))
$md5 = ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($bytes)) -replace '-', '').ToLower()
$b64 = [Convert]::ToBase64String($bytes, 'InsertLineBreaks') -replace "`r", ''
Write-Host "Sending $src ($([math]::Round($bytes.Length/1KB)) KB, md5 $md5) over $Port..." -ForegroundColor Cyan

$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, 'None', 8, 'One'
$sp.DtrEnable = $true; $sp.RtsEnable = $true; $sp.ReadTimeout = 500; $sp.WriteTimeout = 20000
$sp.Open()
try {
    $sp.Write("`r"); Start-Sleep -Milliseconds 600; $null = $sp.ReadExisting()
    # Data must NOT go through bash's line editor (it echoes everything and stalls the link):
    # start base64 reading the tty directly with echo off, stream lines, end with Ctrl-D.
    $sp.Write("stty -echo; base64 -d > /tmp/shell.html.new`r")
    Start-Sleep -Milliseconds 800; $null = $sp.ReadExisting()
    $lines = $b64 -split "`n"
    $i = 0
    foreach ($l in $lines) {
        $sp.Write($l + "`r")
        if ((++$i % 100) -eq 0) { $null = $sp.ReadExisting(); Write-Progress -Activity "Uploading" -PercentComplete (100 * $i / $lines.Count) }
    }
    Start-Sleep -Milliseconds 300
    $sp.Write([string][char]4)   # Ctrl-D at line start = EOF for base64
    Start-Sleep -Milliseconds 800; $null = $sp.ReadExisting()
    Write-Progress -Activity "Uploading" -Completed
    $sp.Write("echo __DEP''BEGIN__; m=`$(md5sum < /tmp/shell.html.new | cut -d' ' -f1); echo got=`$m; if [ `"`$m`" = $md5 ]; then sudo cp -f $dest $dest.prev && sudo install -m 0644 /tmp/shell.html.new $dest && pkill -f -- '--app=file:///usr/share/butteros/shell.html'; echo DEPLOY_OK; else echo DEPLOY_MD5_MISMATCH; fi; rm -f /tmp/shell.html.new; stty echo; echo __DEP''END__`r")
    $buf = ''; $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline -and $buf -notmatch '__DEPEND__') { $buf += $sp.ReadExisting(); Start-Sleep -Milliseconds 200 }
} finally { $sp.Close() }

if ($buf -match '(?s)__DEPBEGIN__(.*?)__DEPEND__') { $r = $Matches[1].Trim() } else { $r = "no reply: $buf" }
Write-Host $r
if ($r -match 'DEPLOY_OK') { Write-Host "Deployed. The UI reloads in a couple of seconds. (.\deploy-shell.ps1 -Rollback to undo)" -ForegroundColor Green }
else { Write-Host "FAILED - phone unchanged." -ForegroundColor Red; exit 1 }
