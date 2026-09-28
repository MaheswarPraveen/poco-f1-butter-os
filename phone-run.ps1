# ==============================================================================
# ADD-ON: run a command on the phone over the ButterOS USB serial console and save
# the output into this project folder (so Claude can read it).
#
#   .\phone-run.ps1                                   # default hardware report -> phone.log
#   .\phone-run.ps1 "uname -a; ip a" -Out net.log     # any command
#   .\phone-run.ps1 -Port COM5                        # if auto-detect picks the wrong port
# ==============================================================================
param(
    [string]$Command = "echo == hwsetup; sudo cat /var/log/butteros-hwsetup.log; echo == nmcli; nmcli dev; echo == services; systemctl --no-pager --plain list-units 'rmtfs*' 'tqftpserv*' 'pd-mapper*' 'butteros*'; echo == dmesg; sudo dmesg | grep -iE 'ath10k|remoteproc|firmware|qcom_q6v5|bluetooth' | tail -80",
    [string]$Out = "phone.log",
    [string]$Port = "",
    [int]$TimeoutSec = 60
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $Port) {
    $ports = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\((COM\d+)\)' -and $_.Name -match 'USB Serial|ButterOS' } |
               ForEach-Object { if ($_.Name -match '\((COM\d+)\)') { $Matches[1] } })
    if ($ports.Count -eq 0) { throw "No USB serial port found. Is ButterOS booted and the USB cable in? (Device Manager > Ports should show 'USB Serial Device (COMx)')" }
    if ($ports.Count -gt 1) { throw "Several serial ports found ($($ports -join ', ')). Re-run with -Port COMx." }
    $Port = $ports[0]
}
Write-Host "Using $Port" -ForegroundColor Cyan

$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, 'None', 8, 'One'
$sp.DtrEnable = $true; $sp.RtsEnable = $true
$sp.NewLine = "`n"; $sp.ReadTimeout = 500
$sp.ReadBufferSize = 65536 # ADD-ON: default 4 KB overflowed on big outputs; 4 MB made usbser close the port
$sp.Open()
try {
    $sp.Write("`r"); Start-Sleep -Milliseconds 800; $null = $sp.ReadExisting()   # wake the auto-login shell
    # Markers are split with '' so the echoed command line never matches them.
    $sp.Write("export TERM=dumb PAGER=cat SYSTEMD_PAGER=cat; stty -echo 2>/dev/null; echo __BUTTER''BEGIN__; { $Command ; } 2>&1; echo __BUTTER''END__`r")
    $buf = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $null = $buf.Append($sp.ReadExisting())
        if ($buf.ToString() -match '(?m)^__BUTTEREND__') { break }
        Start-Sleep -Milliseconds 50
    }
    $sp.Write("stty echo 2>/dev/null`r")
} finally { $sp.Close() }

$esc = [char]27   # Windows PowerShell 5.1 has no `e escape
$text = $buf.ToString() -replace "$esc\[[0-9;?]*[A-Za-z]", '' -replace "`r", ''
if ($text -match '(?s)__BUTTERBEGIN__\n(.*?)__BUTTEREND__') {
    $result = $Matches[1]
} else {
    $result = "[phone-run] no complete output within $TimeoutSec s. Raw capture:`n$text"
}
Set-Content -Path $Out -Value $result -Encoding UTF8
Write-Host "Saved to $Out ($(($result -split "`n").Count) lines)" -ForegroundColor Green
