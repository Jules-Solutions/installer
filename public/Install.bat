@echo off
setlocal

:: Jules.Solutions Installer
:: Download, double-click, done.

title Jules.Solutions Installer
color 0F

echo.
echo   ============================================
echo       Jules.Solutions Installer
echo   ============================================
echo.
echo   Press any key to begin...
pause >nul

set "PS="
where pwsh >nul 2>&1 && set "PS=pwsh"
if not defined PS where powershell >nul 2>&1 && set "PS=powershell"
if not defined PS (
    echo   [ERROR] PowerShell not found!
    pause
    exit /b 1
)

%PS% -ExecutionPolicy Bypass -NoProfile -Command "irm 'https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1' | iex"
pause
