@echo off
title Poco F1 ButterOS Screen Mirror
color 06
echo ========================================================
echo   Launching Poco F1 (beryllium) Screen Mirror...
echo ========================================================
echo.

set "SCRCPY_PATH=C:\Users\xczma\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1\scrcpy.exe"

if exist "%SCRCPY_PATH%" (
    "%SCRCPY_PATH%" --window-title "Poco F1 (beryllium) - ButterOS" --stay-awake --max-fps 60
) else (
    echo [INFO] Searching system PATH for scrcpy...
    scrcpy --window-title "Poco F1 (beryllium) - ButterOS" --stay-awake --max-fps 60
)

if %ERRORLEVEL% neq 0 (
    echo.
    echo [!] Process exited with error code %ERRORLEVEL%.
    echo Please make sure your Poco F1 is connected via USB and unlocked.
    pause
)
