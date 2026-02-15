@echo off
title PXHB Requirement Installer
color 0b

echo ========================================================
echo   PXHB External - Requirement Installer
echo ========================================================
echo.
echo [1/2] Checking for Visual C++ Redistributables...
echo.

winget install Microsoft.VCRedist.2015+.x64

echo.
echo [2/2] Checking for DirectX Runtime...
echo.

winget install Microsoft.DirectX

echo.
echo ========================================================
echo   Requirements installed!
echo   You can now run PXHB_External.exe
echo ========================================================
echo.
pause
