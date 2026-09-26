@echo off
echo ========================================================
echo   ButterOS: Debian ARM64 RootFS Builder for Poco F1
echo ========================================================
echo.
echo Launching WSL2 Ubuntu to assemble Debian 13 (Trixie) ARM64 rootfs...
wsl -u root -d Ubuntu -e bash -c "cd /mnt/c/Users/xczma/.gemini/antigravity/scratch/poco-f1-butter-os/debian-butteros && chmod +x build_debian_rootfs.sh && ./build_debian_rootfs.sh"
echo.
echo ========================================================
echo   Process finished.
echo ========================================================
pause
