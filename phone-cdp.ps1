# ==============================================================================
# ADD-ON dev tool: inspect the live ButterOS UI on the phone over the USB serial console.
#   .\phone-cdp.ps1 -Shot                 -> phone-screen.jpg (what the shell shows right now)
#   .\phone-cdp.ps1 -Eval "document.title" -> result printed
# Uses tools\cdp.py on the phone (installed to /usr/local/bin/butteros-cdp on first use).
# ==============================================================================
param([switch]$Shot, [switch]$Screen, [string]$Eval = "", [string]$Port = "COM5", [double]$Scale = 0.5, [string]$Out = "phone-screen.jpg")
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# install / update the phone-side tool if its md5 differs
$bytes = [IO.File]::ReadAllBytes((Resolve-Path "tools\cdp.py"))
$md5 = ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($bytes)) -replace '-', '').ToLower()
& .\phone-run.ps1 -Port $Port -Out "$env:TEMP\cdpchk.log" -TimeoutSec 20 "md5sum < /usr/local/bin/butteros-cdp 2>/dev/null | cut -d' ' -f1" | Out-Null
if ((Get-Content "$env:TEMP\cdpchk.log" -Raw) -notmatch $md5) {
    $b = [Convert]::ToBase64String($bytes)
    for ($i = 0; $i -lt $b.Length; $i += 1200) {
        $c = $b.Substring($i, [Math]::Min(1200, $b.Length - $i)); $op = if ($i -eq 0) { '>' } else { '>>' }
        & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\c.log" -TimeoutSec 20 "printf %s '$c' $op /tmp/cdp.b64" | Out-Null
    }
    & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\c.log" -TimeoutSec 20 "base64 -d /tmp/cdp.b64 > /tmp/cdp.py && sudo install -m 0755 /tmp/cdp.py /usr/local/bin/butteros-cdp && echo OK" | Out-Null
}

if ($Shot) {
    if ($Screen) {
        # whole display incl. real app windows (grim), same verified chunked pull as below
        & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\shot.log" -TimeoutSec 60 "WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 grim -s $Scale -t png -l 9 /tmp/butteros-shot.jpg && echo __SHOT_MD5__ `$(md5sum < /tmp/butteros-shot.jpg | cut -c1-32) `$(stat -c %s /tmp/butteros-shot.jpg)" | Out-Null
    } else {
    & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\shot.log" -TimeoutSec 60 "butteros-cdp shot $Scale 50" | Out-Null
    }
    $raw = Get-Content "$env:TEMP\shot.log" -Raw
    if ($raw -notmatch '__SHOT_MD5__ ([0-9a-f]{32}) (\d+)') { Write-Host "Screenshot failed:`n$raw"; return }
    $want = $Matches[1]; $size = [int]$Matches[2]
    # pull in 3 KB pieces, each with its own md5, retrying a piece until it arrives intact
    $ms = New-Object IO.MemoryStream; $piece = 3072
    for ($off = 0; $off -lt $size; $off += $piece) {
        $blk = [int][Math]::Floor($off / $piece)
        for ($try = 0; $try -lt 5; $try++) {
            & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\piece.log" -TimeoutSec 20 "dd if=/tmp/butteros-shot.jpg bs=$piece skip=$blk count=1 2>/dev/null > /tmp/p; md5sum < /tmp/p | cut -c1-32; base64 -w0 /tmp/p; echo" | Out-Null
            $l = @(Get-Content "$env:TEMP\piece.log")
            try {
                $bytes = [Convert]::FromBase64String($l[1].Trim())
                $m = ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($bytes)) -replace '-', '').ToLower()
                if ($m -eq $l[0].Trim()) { $ms.Write($bytes, 0, $bytes.Length); break }
            } catch {}
        }
    }
    $img = $ms.ToArray()
    $got = ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($img)) -replace '-', '').ToLower()
    [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot $Out), $img)
    if ($got -eq $want) { Write-Host "Saved $Out (verified, $size bytes)" } else { Write-Host "Saved $Out but CHECKSUM MISMATCH" -ForegroundColor Red }
}
if ($Eval) {
    $e64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Eval))
    & .\phone-run.ps1 -Port $Port -Out "$env:TEMP\eval.log" -TimeoutSec 40 "butteros-cdp eval `"`$(echo $e64 | base64 -d)`"" | Out-Null
    Get-Content "$env:TEMP\eval.log"
}

