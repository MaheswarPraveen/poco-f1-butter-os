# ==============================================================================
# ADD-ON dev tool: install one small file on the running phone over the serial console,
# md5-verified (chunked base64; installs only if the checksum matches).
#   .\install-file.ps1 -Src debian-butteros\configs\x.sh -Dst /usr/local/bin/x [-Mode 0755]
# ==============================================================================
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Dst, [string]$Mode = "0755", [string]$Port = "COM5")
Set-Location $PSScriptRoot
$want = (Get-FileHash $Src -Algorithm MD5).Hash.ToLower()
$b = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Src)))
for ($i = 0; $i -lt $b.Length; $i += 1200) {
    $c = $b.Substring($i, [Math]::Min(1200, $b.Length - $i)); $op = if ($i -eq 0) { '>' } else { '>>' }
    & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\c.log" -TimeoutSec 20 "printf %s '$c' $op /tmp/if.b64" | Out-Null
}
& .\phone-run.ps1 -Port $Port -Out "$env:TEMP\if.log" -TimeoutSec 30 "base64 -d /tmp/if.b64 > /tmp/if.bin; [ `$(md5sum < /tmp/if.bin | cut -c1-32) = $want ] && sudo install -D -m $Mode /tmp/if.bin $Dst && echo INSTALL_OK" | Out-Null
if ((Get-Content "$env:TEMP\if.log" -Raw) -match 'INSTALL_OK') { Write-Host "ok   $Dst" -ForegroundColor Green } else { Write-Host "FAIL $Dst" -ForegroundColor Red; exit 1 }
