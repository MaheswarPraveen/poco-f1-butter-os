# ==============================================================================
# ADD-ON: join a Wi-Fi network on the phone from the PC, over the USB serial console.
# Prompts locally (password hidden); the password is sent base64-wrapped so quotes or
# symbols in it can't break the command, and is never written to a log here.
#
#   .\connect-wifi.ps1
# ==============================================================================
param([string]$Port = "COM5", [string]$Ssid = "")
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$ssid = if ($Ssid) { $Ssid } else { Read-Host "Wi-Fi name (SSID)" }
Write-Host "Connecting the phone to: $ssid" -ForegroundColor Cyan
$sec  = Read-Host "Password (leave empty for an open network)" -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

function B64([string]$s) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
$s64 = B64 $ssid; $p64 = B64 $pass
$pw = if ($pass) { "password `"`$(echo $p64 | base64 -d)`"" } else { "" }
# rescan first: nmcli only connects to networks in its current scan cache ("No network with SSID found")
# and match ignoring leading/trailing spaces: phone hotspots often have a hidden trailing space
# ("realme GT 8 Pro "); connect with the exact broadcast name.
$cmd = "unset HISTFILE; IN=`"`$(echo $s64 | base64 -d)`"; S=`"`$IN`"; for i in 1 2 3; do sudo nmcli dev wifi rescan ifname wlan0 2>/dev/null; sleep 4; F=`"`$(sudo nmcli -t -f SSID dev wifi list ifname wlan0 | awk -v s=`"`$IN`" '{t=`$0; gsub(/^ +| +`$/,`"`",t); u=s; gsub(/^ +| +`$/,`"`",u)} t==u {print; exit}')`"; [ -n `"`$F`" ] && { S=`"`$F`"; echo `"found: [`$S]`"; break; }; done; sudo nmcli dev wifi connect `"`$S`" ifname wlan0 $pw 2>&1 | sed 's/password.*/password ***/'; sleep 3; nmcli -t -f DEVICE,STATE,CONNECTION dev | grep '^wlan0'; nmcli -g IP4.ADDRESS dev show wlan0; curl -sI -m 8 https://deb.debian.org >/dev/null 2>&1 && echo INTERNET_OK || echo NO_INTERNET"   # ping isn't installed on the image
$pass = $null; $p64 = $null

Write-Host "Scanning and connecting (up to ~40 s)..." -ForegroundColor Cyan
& .\phone-run.ps1 -Port $Port -Out wifi.log -TimeoutSec 120 $cmd
Get-Content wifi.log
if ((Get-Content wifi.log -Raw) -match 'INTERNET_OK') { Write-Host "Connected and online." -ForegroundColor Green }
else { Write-Host "Not online yet - see the error above (e.g. 'Secrets were required' = wrong password, 'No network' = not in range/hidden)." -ForegroundColor Yellow }
