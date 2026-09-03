@echo off
echo ===================================================
echo   Installing Indoor Navigation APK to Android Device
echo ===================================================

set "PATH=D:\Android\Sdk\platform-tools;%PATH%"

echo Checking connected devices...
adb devices

echo.
echo Installing app-release.apk...
adb install -r "D:\vel\in_gokul_app\build\app\outputs\flutter-apk\app-release.apk"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ===================================================
    echo   Installation Successful!
    echo ===================================================
) else (
    echo.
    echo Installation failed. Ensure your phone has USB Debugging enabled and is connected.
)

pause
