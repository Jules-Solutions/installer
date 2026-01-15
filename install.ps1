# Jules.Solutions Installer
# https://github.com/Jules-Solutions/installer
# Usage: irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex

$ErrorActionPreference = 'Continue'

# App catalog - add apps here
$Apps = @{
    "DevCLI" = @{
        Repo = "Jul352mf/DevCLI"
        Description = "AI-powered development assistant"
        Private = $true
        Installer = "scripts/installer/Install-GUI.ps1"
        InstallerDeps = @(
            "scripts/installer/setup/config.ps1",
            "scripts/installer/setup/lib/gui-helpers.ps1",
            "scripts/installer/setup/install-deps.ps1",
            "scripts/installer/setup/install-devcli.ps1",
            "scripts/installer/setup/install-vault.ps1",
            "scripts/installer/setup/install-vscode.ps1"
        )
    }
}

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
    
    # Check if private app needs auth
    if ($AppInfo.Private) {
        if (-not (Test-GitHubAuth)) {
            if (-not (Invoke-GitHubAuth)) {
                return $false
            }
        }
        
        # Create temp directory for installer files
        $installerDir = Join-Path $env:TEMP "JulesSolutions-Installer"
        if (Test-Path $installerDir) { Remove-Item $installerDir -Recurse -Force }
        New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $installerDir "setup") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $installerDir "setup\lib") -Force | Out-Null
        
        # Download all installer dependencies
        Write-Host "  Downloading installer files..." -ForegroundColor Gray
        foreach ($dep in $AppInfo.InstallerDeps) {
            $content = Get-PrivateFile -Repo $AppInfo.Repo -Path $dep
            if (-not $content) {
                Write-Host "  [ERROR] Failed to download: $dep" -ForegroundColor Red
                return $false
            }
            $localPath = Join-Path $installerDir ($dep -replace "scripts/installer/", "")
            Set-Content -Path $localPath -Value $content -Encoding UTF8
            Write-Host "    [OK] $($dep.Split('/')[-1])" -ForegroundColor DarkGray
        }
        
        # Download main installer
        $installer = Get-PrivateFile -Repo $AppInfo.Repo -Path $AppInfo.Installer
        if (-not $installer) {
            Write-Host "  [ERROR] Failed to download installer" -ForegroundColor Red
            return $false
        }
        $installerPath = Join-Path $installerDir "Install-GUI.ps1"
        Set-Content -Path $installerPath -Value $installer -Encoding UTF8
        Write-Host "    [OK] Install-GUI.ps1" -ForegroundColor DarkGray
        
        # Launch the GUI installer
        Write-Host ""
        Write-Host "  Launching installer..." -ForegroundColor Cyan
        & $installerPath
        
    } else {
        # Public app - direct download and run
        $url = "https://raw.githubusercontent.com/$($AppInfo.Repo)/main/$($AppInfo.Installer)"
        $installer = Invoke-RestMethod $url
        $tempPath = Join-Path $env:TEMP "Install-$AppName.ps1"
        Set-Content -Path $tempPath -Value $installer -Encoding UTF8
        & $tempPath
    }
    
    return $true
}

# Main
Write-Banner

# Currently just install DevCLI (can expand to app selection menu later)
$selectedApp = "DevCLI"

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
    # GUI handles its own completion message
    Write-Host ""
}
