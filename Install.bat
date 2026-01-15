@echo off
setlocal EnableDelayedExpansion

:: ============================================
:: Jules.Solutions Installer
:: https://github.com/Jules-Solutions/installer
:: ============================================

title Jules.Solutions Installer
color 0F

echo.
echo   ============================================
echo       Jules.Solutions Installer
echo   ============================================
echo.
echo   This installer will set up:
echo     - DevCLI (AI development assistant)
echo     - Your personal .Life vault
echo.

:: Find PowerShell
set "PS="
where pwsh >nul 2>&1 && set "PS=pwsh"
if not defined PS where powershell >nul 2>&1 && set "PS=powershell"
if not defined PS (
    echo   [ERROR] PowerShell not found!
    pause
    exit /b 1
)

:: Run the PowerShell installer
%PS% -ExecutionPolicy Bypass -NoProfile -Command "irm 'https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1' | iex"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   [!] Installation encountered an issue.
    pause
    exit /b 1
)

echo.
pause
