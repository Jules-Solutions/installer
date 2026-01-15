# Jules.Solutions Installer
# https://github.com/Jules-Solutions/installer
#
# Usage:
#   Install:   irm https://jules.solutions/install | iex
#   Update:    irm https://jules.solutions/install | iex -Mode Update
#   Uninstall: irm https://jules.solutions/install | iex -Mode Uninstall
#
# Or with app selection:
#   irm https://jules.solutions/install | iex -App devcli

param(
    [ValidateSet("Install", "Update", "Uninstall", "Menu")]
    [string]$Mode = "Menu",
    
    [string]$App = ""
)

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
        InstallPath = "$env:LOCALAPPDATA\Jules.Solutions\apps\devcli"
    }
    # Future apps can be added here:
    # "xlife" = @{ ... }
    # "buildora" = @{ ... }
}
$DefaultApp = "devcli"

# ============================================================================
# HELPERS
# ============================================================================
function Write-Banner {
    param([string]$Title = "Jules.Solutions")
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "      $Title" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Menu {
    Write-Host "  What would you like to do?" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Install   - Fresh installation" -ForegroundColor Green
    Write-Host "  [2] Update    - Update to latest version" -ForegroundColor Yellow
    Write-Host "  [3] Uninstall - Remove application" -ForegroundColor Red
    Write-Host "  [Q] Quit" -ForegroundColor Gray
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

function Test-AppInstalled {
    param([hashtable]$AppConfig)
    return Test-Path $AppConfig.InstallPath
}

function Get-InstalledVersion {
    param([hashtable]$AppConfig)
    $versionFile = Join-Path $AppConfig.InstallPath "install\manifest.json"
    if (Test-Path $versionFile) {
        try {
            $manifest = Get-Content $versionFile -Raw | ConvertFrom-Json
            return $manifest.version
        } catch { }
    }
    return "unknown"
}

# ============================================================================
# MODE HANDLERS
# ============================================================================
function Invoke-Install {
    param([hashtable]$AppConfig, [string]$AppId)
    
    Write-Banner "Installing $($AppConfig.DisplayName)"
    
    # Download manifest
    Write-Host "  Fetching app configuration..." -ForegroundColor Gray
    $manifestJson = Get-GitHubFile -Repo $AppConfig.Repo -Path $AppConfig.ManifestPath
    
    if (-not $manifestJson) {
        Write-Host "  [ERROR] Failed to fetch manifest" -ForegroundColor Red
        return $false
    }
    
    $manifest = $manifestJson | ConvertFrom-Json
    Write-Host "  [OK] $($manifest.name) v$($manifest.version)" -ForegroundColor Green
    
    # Download GUI installer
    Write-Host "`n  Downloading installer..." -ForegroundColor Gray
    $guiScript = Get-GitHubFile -Repo $AppConfig.Repo -Path "install/gui/Install-GUI.ps1"
    
    if (-not $guiScript) {
        Write-Host "  [ERROR] Failed to download installer" -ForegroundColor Red
        return $false
    }
    
    # Save GUI and manifest to temp files
    $tempGui = Join-Path $env:TEMP "JS-Install-GUI.ps1"
    $tempManifest = Join-Path $env:TEMP "JS-manifest.json"
    Set-Content -Path $tempGui -Value $guiScript -Encoding UTF8
    Set-Content -Path $tempManifest -Value $manifestJson -Encoding UTF8
    Write-Host "  [OK] Ready" -ForegroundColor Green
    
    Write-Host "`n  Launching installer..." -ForegroundColor Cyan
    Write-Host ""
    
    # Run GUI with manifest (use Windows PowerShell for WPF)
    $psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    & $psExe -ExecutionPolicy Bypass -NoProfile -Command "`$m = Get-Content '$tempManifest' -Raw | ConvertFrom-Json; & '$tempGui' -Manifest `$m -Repo '$($AppConfig.Repo)'"
    
    return $true
}

function Invoke-Update {
    param([hashtable]$AppConfig, [string]$AppId)
    
    Write-Banner "Updating $($AppConfig.DisplayName)"
    
    if (-not (Test-AppInstalled $AppConfig)) {
        Write-Host "  [ERROR] $($AppConfig.DisplayName) is not installed" -ForegroundColor Red
        Write-Host "  Run the installer to install it first." -ForegroundColor Gray
        return $false
    }
    
    $currentVersion = Get-InstalledVersion $AppConfig
    Write-Host "  Current version: $currentVersion" -ForegroundColor Gray
    
    # Pull latest from repo
    Write-Host "`n  Updating from GitHub..." -ForegroundColor Yellow
    
    Push-Location $AppConfig.InstallPath
    try {
        $result = git pull 2>&1
        $result | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [ERROR] Git pull failed" -ForegroundColor Red
            return $false
        }
        
        # Re-sync Python dependencies
        Write-Host "`n  Updating dependencies..." -ForegroundColor Yellow
        $uvResult = uv sync 2>&1
        $uvResult | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        
        # Run migrations if database exists
        $dbUrl = [Environment]::GetEnvironmentVariable('DEVCLI_DB_URL', 'User')
        if ($dbUrl) {
            Write-Host "`n  Running database migrations..." -ForegroundColor Yellow
            $migrateResult = uv run devcli db migrate 2>&1
            $migrateResult | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        
        # Update vault templates (merge, don't overwrite)
        $vaultPath = [Environment]::GetEnvironmentVariable('JULES_VAULT', 'User')
        if ($vaultPath -and (Test-Path $vaultPath)) {
            Write-Host "`n  Syncing vault templates..." -ForegroundColor Yellow
            $templatePath = Join-Path $AppConfig.InstallPath "templates\xlife\vault"
            if (Test-Path $templatePath) {
                # Use robocopy for merge (only copy new files, don't overwrite)
                $robocopyResult = robocopy $templatePath $vaultPath /E /XC /XN /XO /NJH /NJS 2>&1
                Write-Host "    Templates synced (new files only)" -ForegroundColor DarkGray
            }
        }
        
        $newVersion = Get-InstalledVersion $AppConfig
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "    Update Complete!" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "    $currentVersion -> $newVersion" -ForegroundColor White
        Write-Host ""
        
    } finally {
        Pop-Location
    }
    
    return $true
}

function Invoke-Uninstall {
    param([hashtable]$AppConfig, [string]$AppId)
    
    Write-Banner "Uninstalling $($AppConfig.DisplayName)"
    
    if (-not (Test-AppInstalled $AppConfig)) {
        Write-Host "  [INFO] $($AppConfig.DisplayName) is not installed" -ForegroundColor Yellow
        return $true
    }
    
    # Confirm
    Write-Host "  This will remove:" -ForegroundColor Yellow
    Write-Host "    - Application files: $($AppConfig.InstallPath)" -ForegroundColor Gray
    Write-Host "    - Environment variables (JULES_*, DEVCLI_*)" -ForegroundColor Gray
    Write-Host "    - PATH entries" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Your vault and data will NOT be deleted." -ForegroundColor Green
    Write-Host ""
    $confirm = Read-Host "  Type 'yes' to confirm"
    
    if ($confirm -ne 'yes') {
        Write-Host "  Cancelled." -ForegroundColor Gray
        return $false
    }
    
    Write-Host ""
    
    # Stop Docker container if running
    Write-Host "  Stopping database container..." -ForegroundColor Yellow
    $null = docker stop devcli-postgres 2>&1
    $null = docker rm devcli-postgres 2>&1
    Write-Host "    [OK] Container stopped" -ForegroundColor Green
    
    # Remove application directory
    Write-Host "  Removing application files..." -ForegroundColor Yellow
    if (Test-Path $AppConfig.InstallPath) {
        Remove-Item -Path $AppConfig.InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    [OK] Application removed" -ForegroundColor Green
    }
    
    # Remove bin wrapper
    $binPath = "$env:LOCALAPPDATA\Jules.Solutions\bin"
    $wrapperPath = Join-Path $binPath "devcli.cmd"
    if (Test-Path $wrapperPath) {
        Remove-Item $wrapperPath -Force
        Write-Host "    [OK] Wrapper removed" -ForegroundColor Green
    }
    
    # Remove environment variables
    Write-Host "  Removing environment variables..." -ForegroundColor Yellow
    $envVars = @(
        'JULES_HOME', 'JULES_VAULT',
        'DEVCLI_VAULT', 'DEVCLI_DB_URL', 'DEVCLI_DB_HOST', 'DEVCLI_DB_PORT',
        'DEVCLI_DB_NAME', 'DEVCLI_DB_USER', 'DEVCLI_DB_PASSWORD',
        'UV_CACHE_DIR'
    )
    foreach ($var in $envVars) {
        [Environment]::SetEnvironmentVariable($var, $null, 'User')
    }
    Write-Host "    [OK] Environment cleaned" -ForegroundColor Green
    
    # Remove from PATH
    Write-Host "  Cleaning PATH..." -ForegroundColor Yellow
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $pathParts = $userPath -split ';' | Where-Object { $_ -notmatch 'Jules\.Solutions' }
    $newPath = $pathParts -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "    [OK] PATH cleaned" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "    Uninstall Complete!" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Your vault remains at:" -ForegroundColor Gray
    $vault = [Environment]::GetEnvironmentVariable('JULES_VAULT', 'User')
    if (-not $vault) {
        $vault = "$env:USERPROFILE\*.Life"
    }
    Write-Host "    $vault" -ForegroundColor White
    Write-Host ""
    Write-Host "  To completely remove data:" -ForegroundColor Gray
    Write-Host "    - Delete your vault folder" -ForegroundColor Gray
    Write-Host "    - Run: docker volume rm devcli-pgdata" -ForegroundColor Gray
    Write-Host ""
    
    return $true
}

# ============================================================================
# MAIN
# ============================================================================
Write-Banner

# Select app
$appId = if ($App) { $App } else { $DefaultApp }
if (-not $Apps.ContainsKey($appId)) {
    Write-Host "  [ERROR] Unknown app: $appId" -ForegroundColor Red
    Write-Host "  Available apps: $($Apps.Keys -join ', ')" -ForegroundColor Gray
    exit 1
}
$appConfig = $Apps[$appId]

# Show current status
$isInstalled = Test-AppInstalled $appConfig
if ($isInstalled) {
    $version = Get-InstalledVersion $appConfig
    Write-Host "  $($appConfig.DisplayName) v$version is installed" -ForegroundColor Green
} else {
    Write-Host "  $($appConfig.DisplayName) is not installed" -ForegroundColor Yellow
}
Write-Host ""

# Menu mode - launch GUI directly with mode selection
if ($Mode -eq "Menu") {
    # Download GUI from PUBLIC installer repo via API (bypasses CDN cache)
    Write-Host "  Downloading installer..." -ForegroundColor Gray
    try {
        # Use GitHub API to get file content (avoids raw.githubusercontent.com 5-min cache)
        $apiUrl = "https://api.github.com/repos/Jules-Solutions/installer/contents/src/gui/Install-GUI.ps1"
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ Accept = "application/vnd.github.v3+json" }
        $guiScript = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($response.content))
    } catch {
        Write-Host "  [ERROR] Failed to download GUI: $_" -ForegroundColor Red
        Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
    
    # Ensure gh CLI for manifest from private repo
    if (-not (Install-GitHubCLI)) {
        Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
    
    # Auth if needed for private repo
    if ($appConfig.Private -and -not (Test-GitHubAuth)) {
        if (-not (Invoke-GitHubAuth)) {
            Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
    }
    
    # Download manifest from app repo (may be private)
    $manifestJson = Get-GitHubFile -Repo $appConfig.Repo -Path $appConfig.ManifestPath
    
    if (-not $manifestJson) {
        Write-Host "  [ERROR] Failed to download app manifest" -ForegroundColor Red
        Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
    
    $tempGui = Join-Path $env:TEMP "JS-Install-GUI.ps1"
    $tempManifest = Join-Path $env:TEMP "JS-manifest.json"
    Set-Content -Path $tempGui -Value $guiScript -Encoding UTF8
    Set-Content -Path $tempManifest -Value $manifestJson -Encoding UTF8
    Write-Host "  [OK] Ready" -ForegroundColor Green
    
    Write-Host "`n  Launching installer..." -ForegroundColor Cyan
    
    $psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    & $psExe -ExecutionPolicy Bypass -NoProfile -Command "`$m = Get-Content '$tempManifest' -Raw | ConvertFrom-Json; & '$tempGui' -Manifest `$m -Repo '$($appConfig.Repo)' -Mode Menu"
    
    exit 0
}

# Ensure gh CLI for Install/Update
if ($Mode -in @("Install", "Update")) {
    if (-not (Install-GitHubCLI)) {
        Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit 1
    }
    
    # Auth if needed
    if ($appConfig.Private -and -not (Test-GitHubAuth)) {
        if (-not (Invoke-GitHubAuth)) {
            Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
    }
}

# Execute selected mode
$success = switch ($Mode) {
    "Install"   { Invoke-Install -AppConfig $appConfig -AppId $appId }
    "Update"    { Invoke-Update -AppConfig $appConfig -AppId $appId }
    "Uninstall" { Invoke-Uninstall -AppConfig $appConfig -AppId $appId }
}

if (-not $success) {
    Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

Write-Host "  Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
