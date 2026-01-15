<#
.SYNOPSIS
    Jules.Solutions Installer Orchestrator
.DESCRIPTION
    Main entry point that loads app registry, fetches manifests, and launches GUI.
.PARAMETER App
    App ID to install (default: uses registry defaultApp)
.PARAMETER NoGui
    Run in console mode without GUI
.EXAMPLE
    .\Invoke-Installer.ps1
    .\Invoke-Installer.ps1 -App devcli
    .\Invoke-Installer.ps1 -NoGui
#>

[CmdletBinding()]
param(
    [string]$App,
    [switch]$NoGui
)

$ErrorActionPreference = 'Continue'
$scriptRoot = $PSScriptRoot

# Import libraries
. "$scriptRoot\lib\auth.ps1"
. "$scriptRoot\lib\download.ps1"
. "$scriptRoot\lib\manifest.ps1"

# ============================================================================
# BANNER
# ============================================================================
function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "      Jules.Solutions Installer" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# MAIN
# ============================================================================
Write-Banner

# Load app registry
$registryPath = Join-Path $scriptRoot "..\apps\registry.json"
if (-not (Test-Path $registryPath)) {
    Write-Host "  [ERROR] App registry not found" -ForegroundColor Red
    exit 1
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

# Determine which app to install
if (-not $App) {
    $App = $registry.defaultApp
}

if (-not $registry.apps.$App) {
    Write-Host "  [ERROR] Unknown app: $App" -ForegroundColor Red
    Write-Host "  Available apps:" -ForegroundColor Gray
    $registry.apps.PSObject.Properties | ForEach-Object {
        Write-Host "    - $($_.Name): $($_.Value.description)" -ForegroundColor Gray
    }
    exit 1
}

$appInfo = $registry.apps.$App
Write-Host "  App: $($appInfo.displayName)" -ForegroundColor White
Write-Host "  $($appInfo.description)" -ForegroundColor Gray
Write-Host ""

# Install gh CLI if needed
if (-not (Install-GitHubCLI)) {
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Authenticate if private repo
if ($appInfo.private) {
    Write-Host "  Checking authentication..." -ForegroundColor Gray
    if (-not (Test-GitHubAuth)) {
        if (-not (Invoke-GitHubAuth)) {
            Write-Host ""
            Write-Host "  Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
    } else {
        Write-Host "  [OK] Authenticated" -ForegroundColor Green
    }
}

# Download manifest
Write-Host ""
Write-Host "  Fetching app manifest..." -ForegroundColor Gray
$manifest = Get-AppManifest -Repo $appInfo.repo -ManifestPath $appInfo.manifestPath

if (-not $manifest) {
    Write-Host "  [ERROR] Failed to fetch manifest from $($appInfo.repo)" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] $($manifest.name) v$($manifest.version)" -ForegroundColor Green
Write-Host ""

# Launch installer
if ($NoGui) {
    # Console mode - not implemented yet
    Write-Host "  Console mode not yet implemented. Use GUI." -ForegroundColor Yellow
    exit 1
} else {
    # GUI mode
    $guiScript = Join-Path $scriptRoot "gui\Install-GUI.ps1"
    & $guiScript -Manifest $manifest -Repo $appInfo.repo
}
