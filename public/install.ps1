# Jules.Solutions Installer
# https://github.com/Jules-Solutions/installer
# Usage: irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex

$ErrorActionPreference = 'Continue'

# ============================================================================
# APP REGISTRY (inline for single-file distribution)
# ============================================================================
$Apps = @{
    "devcli" = @{
        Repo = "Jul352mf/DevCLI"
        ManifestPath = "install/manifest.json"
        DisplayName = "DevCLI"
        Description = "AI-powered development assistant"
        Private = $true
    }
}
$DefaultApp = "devcli"

# ============================================================================
# HELPERS
# ============================================================================
function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "      Jules.Solutions Installer" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Install-GitHubCLI {
    Write-Host "  Checking GitHub CLI..." -ForegroundColor Gray
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] GitHub CLI available" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [ERROR] winget not found" -ForegroundColor Red
        return $false
    }
    
    $null = winget install GitHub.cli --accept-source-agreements --accept-package-agreements 2>&1
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] GitHub CLI installed" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  [ERROR] Installation failed" -ForegroundColor Red
    return $false
}

function Test-GitHubAuth {
    $null = gh auth status 2>&1
    return $LASTEXITCODE -eq 0
}

function Invoke-GitHubAuth {
    Write-Host ""
    Write-Host "  GitHub authentication required." -ForegroundColor Yellow
    Write-Host "  A browser window will open for login." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Press Enter to continue..." -ForegroundColor Cyan
    $null = Read-Host
    
    Start-Process -FilePath "gh" -ArgumentList "auth", "login", "--web", "-h", "github.com", "-p", "https" -Wait -NoNewWindow
    
    if (Test-GitHubAuth) {
        Write-Host "  [OK] Authenticated" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  [ERROR] Authentication failed" -ForegroundColor Red
    return $false
}

function Get-GitHubFile {
    param([string]$Repo, [string]$Path)
    
    $content = gh api "repos/$Repo/contents/$Path" --jq '.content' 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    
    try {
        return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content))
    } catch {
        return $null
    }
}

# ============================================================================
# MAIN
# ============================================================================
Write-Banner

$appId = $DefaultApp
$app = $Apps[$appId]

Write-Host "  Installing: $($app.DisplayName)" -ForegroundColor White
Write-Host "  $($app.Description)" -ForegroundColor Gray
Write-Host ""

# Ensure gh CLI
if (-not (Install-GitHubCLI)) {
    Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Auth if needed
if ($app.Private -and -not (Test-GitHubAuth)) {
    if (-not (Invoke-GitHubAuth)) {
        Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# Download manifest
Write-Host "`n  Fetching app configuration..." -ForegroundColor Gray
$manifestJson = Get-GitHubFile -Repo $app.Repo -Path $app.ManifestPath

if (-not $manifestJson) {
    Write-Host "  [ERROR] Failed to fetch manifest" -ForegroundColor Red
    Write-Host "  Make sure you have access to $($app.Repo)" -ForegroundColor Gray
    exit 1
}

$manifest = $manifestJson | ConvertFrom-Json
Write-Host "  [OK] $($manifest.name) v$($manifest.version)" -ForegroundColor Green

# Download GUI installer
Write-Host "`n  Downloading installer..." -ForegroundColor Gray
$guiScript = Get-GitHubFile -Repo $app.Repo -Path "install/gui/Install-GUI.ps1"

if (-not $guiScript) {
    # Fallback to old location during transition
    $guiScript = Get-GitHubFile -Repo $app.Repo -Path "scripts/installer/Install-GUI.ps1"
}

if (-not $guiScript) {
    Write-Host "  [ERROR] Failed to download installer" -ForegroundColor Red
    exit 1
}

# Save and run
$tempGui = Join-Path $env:TEMP "JS-Install-GUI.ps1"
Set-Content -Path $tempGui -Value $guiScript -Encoding UTF8
Write-Host "  [OK] Ready" -ForegroundColor Green

Write-Host "`n  Launching installer..." -ForegroundColor Cyan
Write-Host ""

# Run GUI with manifest
& powershell -ExecutionPolicy Bypass -NoProfile -Command "& '$tempGui' -Manifest (`$args[0] | ConvertFrom-Json) -Repo '$($app.Repo)'" -Args $manifestJson
