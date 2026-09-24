$ErrorActionPreference = "Stop"

$jdkDir = "C:\Program Files\Android\Android Studio\jbr"
$jdkBin = Join-Path $jdkDir "bin"
$env:JAVA_HOME = $jdkDir
$env:PATH = "$jdkBin;$env:PATH"

$sdk = "C:\Users\xczma\AppData\Local\Android\Sdk"
$bt = (Get-ChildItem "$sdk\build-tools" | Sort-Object Name -Descending | Select-Object -First 1).FullName
$plat = (Get-ChildItem "$sdk\platforms" | Sort-Object Name -Descending | Select-Object -First 1).FullName
$androidJar = Join-Path $plat "android.jar"

Write-Host "=== 1. COMPILING RESOURCES (AAPT2) ==="
if (Test-Path "compiled_res.zip") { Remove-Item "compiled_res.zip" -Force }
if (Test-Path "obj") { Remove-Item "obj" -Recurse -Force }
New-Item -ItemType Directory -Path "obj" | Out-Null

& "$bt\aapt2.exe" compile --dir res -o compiled_res.zip
Write-Host "Resources compiled to compiled_res.zip"

Write-Host "=== 2. LINKING RESOURCES & ASSETS ==="
if (Test-Path "unaligned.apk") { Remove-Item "unaligned.apk" -Force }
& "$bt\aapt2.exe" link -I $androidJar --manifest AndroidManifest.xml -A assets -o unaligned.apk compiled_res.zip --auto-add-overlay
Write-Host "Linked into unaligned.apk"

Write-Host "=== 3. COMPILING JAVA SOURCE (JAVAC) ==="
& "$jdkBin\javac.exe" -cp $androidJar -d obj src\com\butteros\launcher\MainActivity.java
Write-Host "Compiled MainActivity.class"

Write-Host "=== 4. DEXING BYTECODE (D8) ==="
if (Test-Path "classes.dex") { Remove-Item "classes.dex" -Force }
$classFiles = (Get-ChildItem -Path obj -Filter *.class -Recurse).FullName
& "$bt\d8.bat" --output . --min-api 26 $classFiles
Write-Host "Generated classes.dex: $(Test-Path 'classes.dex')"

Write-Host "=== 5. PACKAGING DEX INTO APK ==="
& "$jdkBin\jar.exe" -uf unaligned.apk classes.dex
Write-Host "Packaged classes.dex into unaligned.apk"

Write-Host "=== 6. ZIPALIGN ==="
if (Test-Path "aligned.apk") { Remove-Item "aligned.apk" -Force }
& "$bt\zipalign.exe" -f -v 4 unaligned.apk aligned.apk | Out-Null
Write-Host "Zipalign complete"

Write-Host "=== 7. SIGNING APK (APKSIGNER) ==="
if (-not (Test-Path "debug.keystore")) {
    Write-Host "Generating debug.keystore..."
    & "$jdkBin\keytool.exe" -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
}

if (Test-Path "butteros-launcher.apk") { Remove-Item "butteros-launcher.apk" -Force }
& "$bt\apksigner.bat" sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out butteros-launcher.apk aligned.apk
Write-Host "APKSIGNER complete! butteros-launcher.apk created: $(Test-Path 'butteros-launcher.apk')"

$apkItem = Get-Item "butteros-launcher.apk"
Write-Host "Final APK Size: $($apkItem.Length) bytes ($([math]::Round($apkItem.Length / 1MB, 2)) MB)"
