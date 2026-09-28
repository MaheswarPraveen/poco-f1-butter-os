# ==============================================================================
# ADD-ON dev tool: copy files to /tmp on the running phone over the USB serial console.
#   .\push-to-phone.ps1 -Files a.sh,b.conf     -> /tmp/a.sh, /tmp/b.conf  (md5-verified)
# Files keep their base names. Install them on the phone with phone-run.ps1 afterwards.
# ==============================================================================
param([Parameter(Mandatory)][string[]]$Files, [string]$Port = "COM5")
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$stage = Join-Path $env:TEMP "butteros-push"
if (Test-Path $stage) { Get-ChildItem $stage | Remove-Item -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($f in $Files) { Copy-Item (Resolve-Path $f) (Join-Path $stage (Split-Path $f -Leaf)) }
$tgz = Join-Path $env:TEMP "butteros-push.tgz"
tar -czf $tgz -C $stage .
$bytes = [IO.File]::ReadAllBytes($tgz)
$md5 = ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($bytes)) -replace '-', '').ToLower()
$b64 = [Convert]::ToBase64String($bytes, 'InsertLineBreaks') -replace "`r", ''

$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, 'None', 8, 'One'
$sp.DtrEnable = $true; $sp.RtsEnable = $true; $sp.ReadTimeout = 500; $sp.WriteTimeout = 20000; $sp.ReadBufferSize = 4MB
$sp.Open()
try {
    $sp.Write("`r"); Start-Sleep -Milliseconds 600; $null = $sp.ReadExisting()
    $sp.Write("stty -echo; base64 -d > /tmp/butteros-push.tgz`r")
    Start-Sleep -Milliseconds 800; $null = $sp.ReadExisting()
    foreach ($l in ($b64 -split "`n")) { $sp.Write($l + "`r") }
    Start-Sleep -Milliseconds 300; $sp.Write([string][char]4); Start-Sleep -Milliseconds 800; $null = $sp.ReadExisting()
    $sp.Write("echo __P''B__; [ `$(md5sum < /tmp/butteros-push.tgz | cut -d' ' -f1) = $md5 ] && tar -xzf /tmp/butteros-push.tgz -C /tmp --no-same-owner && echo PUSH_OK; stty echo; echo __P''E__`r")
    $buf = ''; $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and $buf -notmatch '__PE__') { $buf += $sp.ReadExisting(); Start-Sleep -Milliseconds 100 }
} finally { $sp.Close() }
if ($buf -match 'PUSH_OK') { Write-Host "Pushed to /tmp: $(($Files | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')" -ForegroundColor Green }
else { Write-Host "PUSH FAILED" -ForegroundColor Red; exit 1 }
