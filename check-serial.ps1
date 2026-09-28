# ADD-ON: diagnose the Windows USB-serial (CDC-ACM) driver. Writes serial-check.log here.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\check-serial.ps1
Set-Location $PSScriptRoot
$log = "serial-check.log"
function W($t) { Add-Content -Path $log -Value $t -Encoding UTF8 }
Set-Content -Path $log -Value "== serial check $(Get-Date)" -Encoding UTF8

W "`n== Windows"
W ((Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture | Format-List | Out-String).Trim())

W "`n== Inbox driver files"
foreach ($p in "$env:WINDIR\INF\usbser.inf", "$env:WINDIR\System32\drivers\usbser.sys") {
    if (Test-Path $p) { $f = Get-Item $p; W "OK   $p  $($f.Length) bytes  $($f.VersionInfo.FileVersion)" } else { W "MISSING $p" }
}
W "`n== Driver store entries for usbser"
W ((& pnputil /enum-drivers 2>&1 | Out-String) -split "`r?`n`r?`n" | Where-Object { $_ -match 'usbser' } | Out-String).Trim()

W "`n== usbser service"
W ((& sc.exe qc usbser 2>&1 | Out-String).Trim())
W ((& sc.exe query usbser 2>&1 | Out-String).Trim())

W "`n== Ports class devices (including disconnected)"
W ((Get-PnpDevice -Class Ports -ErrorAction SilentlyContinue | Select-Object Status, FriendlyName, InstanceId | Format-Table -AutoSize -Wrap | Out-String).Trim())

W "`n== Devices with problems (any class)"
W ((Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Status -in @('Error', 'Degraded') } |
    Select-Object Status, Class, FriendlyName, Problem, InstanceId | Format-Table -AutoSize -Wrap | Out-String).Trim())

W "`n== Phone-related USB devices seen on this PC (Xiaomi 2717, Google 18D1, Linux 1D6B/0525)"
W ((Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_(2717|18D1|1D6B|0525|05C6)' } |
    Select-Object Status, Class, FriendlyName, InstanceId | Format-Table -AutoSize -Wrap | Out-String).Trim())

W "`n== Recent driver install events (setupapi) mentioning usbser / Ports"
$sa = "$env:WINDIR\INF\setupapi.dev.log"
if (Test-Path $sa) { W ((Select-String -Path $sa -Pattern 'usbser|mdmcpq|Class_02&SubClass_02|ButterOS' -SimpleMatch:$false | Select-Object -Last 40 | ForEach-Object { $_.Line }) -join "`n") }
else { W "setupapi.dev.log not found" }

Write-Host "Saved $log" -ForegroundColor Green
