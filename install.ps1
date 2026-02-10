# Jules.Solutions Installer
# https://github.com/Jules-Solutions/installer
# Usage: irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex

$ErrorActionPreference = 'Continue'

# App catalog - add apps here
$Apps = [ordered]@{
    "DevCLI" = @{
        Repo = "Jul352mf/DevCLI"
        Description = "AI-powered development assistant"
        Private = $true
        ManifestPath = "install/manifest.json"
    }
    "TotallyLegal" = @{
        Repo = "Jules-Solutions/Open-BAR"
        Description = "Beyond All Reason widget suite (overlays, automation, strategy)"
        Private = $false
        Installer = "install/Install-TotallyLegal.ps1"
    }
}

# GUI installer URL (hosted in this public repo)
$GuiInstallerUrl = "https://raw.githubusercontent.com/Jules-Solutions/installer/main/src/gui/Install-GUI.ps1"

function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "      Jules.Solutions Installer" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-AppMenu {
    <#
    .SYNOPSIS
        Display app selection menu and return the chosen app name
    #>
    Write-Host "  Available applications:" -ForegroundColor White
    Write-Host ""
    
    $index = 1
    $appNames = @($Apps.Keys)
    
    foreach ($name in $appNames) {
        $app = $Apps[$name]
        $privateTag = if ($app.Private) { " (requires GitHub login)" } else { "" }
        Write-Host "    [$index] $name" -ForegroundColor Cyan -NoNewline
        Write-Host "$privateTag" -ForegroundColor DarkGray
        Write-Host "        $($app.Description)" -ForegroundColor Gray
        Write-Host ""
        $index++
    }
    
    Write-Host "    [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
    
    while ($true) {
        $choice = Read-Host "  Select an app (1-$($appNames.Count))"
        
        if ($choice -eq 'Q' -or $choice -eq 'q') {
            return $null
        }
        
        $num = 0
        if ([int]::TryParse($choice, [ref]$num) -and $num -ge 1 -and $num -le $appNames.Count) {
            return $appNames[$num - 1]
        }
        
        # Also accept app name directly
        if ($Apps.Contains($choice)) {
            return $choice
        }
        
        Write-Host "  Invalid choice. Please enter 1-$($appNames.Count) or Q to quit." -ForegroundColor Yellow
    }
}

function Install-GitHubCLI {
    Write-Host "  Checking GitHub CLI..." -ForegroundColor Gray
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] GitHub CLI installed" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    
    # Try winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $null = winget install GitHub.cli --accept-source-agreements --accept-package-agreements 2>&1
        
        # Refresh PATH
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
        
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            Write-Host "  [OK] GitHub CLI installed" -ForegroundColor Green
            return $true
        }
    }
    
    Write-Host "  [ERROR] Failed to install GitHub CLI" -ForegroundColor Red
    Write-Host "  Please install manually: winget install GitHub.cli" -ForegroundColor Yellow
    return $false
}

function Test-GitHubAuth {
    $result = gh auth status 2>&1
    return $LASTEXITCODE -eq 0
}

function Invoke-GitHubAuth {
    Write-Host ""
    Write-Host "  GitHub authentication required for private apps." -ForegroundColor Yellow
    Write-Host "  A browser window will open for login." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Press Enter to open GitHub login..." -ForegroundColor Cyan
    $null = Read-Host
    
    gh auth login --web -h github.com -p https
    
    if (Test-GitHubAuth) {
        Write-Host "  [OK] GitHub authenticated" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  [ERROR] GitHub authentication failed" -ForegroundColor Red
    return $false
}

function Get-PrivateFile {
    param([string]$Repo, [string]$Path)
    
    $content = gh api "repos/$Repo/contents/$Path" --jq '.content' 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content))
}

function Install-App {
    param([string]$AppName, [hashtable]$AppInfo)

    Write-Host ""
    Write-Host "  Installing $AppName..." -ForegroundColor Cyan
    Write-Host "  $($AppInfo.Description)" -ForegroundColor Gray
    Write-Host ""

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch { }

    if ($AppInfo.Private) {
        # Private app: auth → download manifest → download GUI → launch
        if (-not (Test-GitHubAuth)) {
            if (-not (Invoke-GitHubAuth)) {
                return $false
            }
        }

        # Download manifest from private repo
        Write-Host "  Fetching app manifest..." -ForegroundColor Gray
        $manifestJson = Get-PrivateFile -Repo $AppInfo.Repo -Path $AppInfo.ManifestPath

        if (-not $manifestJson) {
            Write-Host "  [ERROR] Failed to fetch manifest from $($AppInfo.Repo)" -ForegroundColor Red
            return $false
        }

        $manifest = $manifestJson | ConvertFrom-Json
        Write-Host "  [OK] $($manifest.name) v$($manifest.version)" -ForegroundColor Green

        # Download GUI installer from public installer repo
        Write-Host "  Downloading installer GUI..." -ForegroundColor Gray

        try {
            $guiContent = Invoke-RestMethod $GuiInstallerUrl -ErrorAction Stop
        } catch {
            Write-Host "  [ERROR] Failed to download GUI installer" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor DarkGray
            return $false
        }

        $guiPath = Join-Path $env:TEMP "Install-GUI.ps1"
        Set-Content -Path $guiPath -Value $guiContent -Encoding UTF8
        Write-Host "  [OK] Ready" -ForegroundColor Green

        # Launch GUI with manifest and repo
        Write-Host ""
        Write-Host "  Launching installer..." -ForegroundColor Cyan
        Write-Host ""
        & $guiPath -Manifest $manifest -Repo $AppInfo.Repo

    } else {
        # Public app - direct download and run
        Write-Host "  Downloading installer..." -ForegroundColor Gray

        $url = "https://raw.githubusercontent.com/$($AppInfo.Repo)/main/$($AppInfo.Installer)"

        try {
            $installer = Invoke-RestMethod $url -ErrorAction Stop
        } catch {
            Write-Host "  [ERROR] Failed to download installer from:" -ForegroundColor Red
            Write-Host "  $url" -ForegroundColor DarkGray
            Write-Host "  $_" -ForegroundColor DarkGray
            return $false
        }

        $tempPath = Join-Path $env:TEMP "Install-$AppName.ps1"
        Set-Content -Path $tempPath -Value $installer -Encoding UTF8
        Write-Host "  [OK] Downloaded" -ForegroundColor Green
        Write-Host ""
        & $tempPath
    }

    return $true
}

# Main
Write-Banner

# Show app selection menu
$selectedApp = Show-AppMenu

if (-not $selectedApp) {
    Write-Host "  Goodbye!" -ForegroundColor Gray
    exit 0
}

# Ensure gh CLI for private apps
if ($Apps[$selectedApp].Private) {
    if (-not (Install-GitHubCLI)) {
        Write-Host ""
        Write-Host "  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
}

# Install the app
$success = Install-App -AppName $selectedApp -AppInfo $Apps[$selectedApp]

if ($success) {
    # App installer handles its own completion message
    Write-Host ""
}
