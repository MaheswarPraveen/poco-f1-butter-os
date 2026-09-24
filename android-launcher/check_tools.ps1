$jdk = "C:\Program Files\Android\Android Studio\jbr\bin"
$sdk = "C:\Users\xczma\AppData\Local\Android\Sdk"
$bt = (Get-ChildItem "$sdk\build-tools" | Sort-Object Name -Descending | Select-Object -First 1).FullName
$plat = (Get-ChildItem "$sdk\platforms" | Sort-Object Name -Descending | Select-Object -First 1).FullName

Write-Host "javac: $(Test-Path "$jdk\javac.exe")"
Write-Host "BuildTools: $bt"
Write-Host "Platform: $plat"
Write-Host "aapt2: $(Test-Path "$bt\aapt2.exe")"
Write-Host "d8: $(Test-Path "$bt\d8.bat")"
Write-Host "zipalign: $(Test-Path "$bt\zipalign.exe")"
Write-Host "apksigner: $(Test-Path "$bt\apksigner.bat")"
