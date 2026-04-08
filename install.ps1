#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Jules.Solutions Platform Installer
    One command to connect to the Jules.Solutions AI platform.

.DESCRIPTION
    Supports two installation tiers:
    - Tier 1 (Full): Local runtime (jules-local) + remote MCP connection
    - Tier 2 (Remote): MCP connection only — no local install

    Cross-platform: Windows, macOS, Linux (PowerShell Core / pwsh)

.EXAMPLE
    # Windows (PowerShell)
    irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex

    # macOS / Linux
    curl -fsSL https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | pwsh -

.LINK
    https://jules.solutions
    https://github.com/Jules-Solutions/installer
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Configuration ───────────────────────────────────────────────────────────

$Script:Config = @{
    AuthURL     = "https://auth.jules.solutions"
    ApiURL      = "https://api.jules.solutions"
    McpURL      = "https://mcp.jules.solutions/sse"
    LocalRepo   = "https://github.com/Jules-Solutions/jules-local.git"
    Version     = "2.0.0"
    ConfigDir   = if ($IsWindows) { Join-Path $env:USERPROFILE ".config" "devcli" } else { Join-Path $HOME ".config" "devcli" }
    McpJsonPath = if ($IsWindows) { Join-Path $env:USERPROFILE ".mcp.json" } else { Join-Path $HOME ".mcp.json" }
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "  $('─' * ($Text.Length + 2))" -ForegroundColor DarkGray
}

function Write-Step {
    param([string]$Text, [string]$Status = "...")
    $color = switch ($Status) {
        "OK"    { "Green" }
        "SKIP"  { "Yellow" }
        "FAIL"  { "Red" }
        default { "White" }
    }
    $icon = switch ($Status) {
        "OK"    { "[+]" }
        "SKIP"  { "[-]" }
        "FAIL"  { "[!]" }
        default { "[>]" }
    }
    Write-Host "  $icon $Text" -ForegroundColor $color
}

function Write-Fatal {
    param([string]$Message)
    Write-Host ""
    Write-Host "  [!] ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    exit 1
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-OSName {
    if ($IsWindows) { return "windows" }
    if ($IsMacOS)   { return "macos" }
    if ($IsLinux)   { return "linux" }
    return "unknown"
}

# ─── Banner ──────────────────────────────────────────────────────────────────

function Show-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                               ║" -ForegroundColor Cyan
    Write-Host "  ║        Jules.Solutions Platform Setup         ║" -ForegroundColor Cyan
    Write-Host "  ║                                               ║" -ForegroundColor Cyan
    Write-Host "  ║   AI agent infrastructure that does work.     ║" -ForegroundColor DarkGray
    Write-Host "  ║                                               ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  v$($Script:Config.Version)  |  $(Get-OSName)" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Step 1: Environment Detection ──────────────────────────────────────────

function Get-Environment {
    Write-Header "Environment Detection"

    $detected = @{
        OS        = Get-OSName
        HasCC     = Test-CommandExists "claude"
        HasUV     = Test-CommandExists "uv"
        HasPython = (Test-CommandExists "python3") -or (Test-CommandExists "python")
        HasCurl   = Test-CommandExists "curl"
    }

    Write-Step "OS: $($detected.OS)" "OK"
    Write-Step "Claude Code: $(if ($detected.HasCC) { 'found' } else { 'not found' })" $(if ($detected.HasCC) { "OK" } else { "SKIP" })
    Write-Step "uv: $(if ($detected.HasUV) { 'found' } else { 'not found' })" $(if ($detected.HasUV) { "OK" } else { "SKIP" })
    Write-Step "Python: $(if ($detected.HasPython) { 'found' } else { 'not found' })" $(if ($detected.HasPython) { "OK" } else { "SKIP" })

    return $detected
}

# ─── Step 2: Tier Selection ─────────────────────────────────────────────────

function Select-Tier {
    param($Env)

    Write-Header "Installation Tier"

    Write-Host ""
    Write-Host "  Choose your setup:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Full Install  — Local runtime + remote MCP connection" -ForegroundColor Green
    Write-Host "      Best for: developers with Claude Code" -ForegroundColor DarkGray
    Write-Host "      Requires: uv (will help install if missing)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [2] Remote Only   — MCP connection only, no local install" -ForegroundColor Yellow
    Write-Host "      Best for: quick access, no local dependencies" -ForegroundColor DarkGray
    Write-Host ""

    do {
        $choice = Read-Host "  Select tier [1/2]"
    } while ($choice -notin @("1", "2"))

    $tier = if ($choice -eq "1") { "full" } else { "remote" }
    Write-Step "Selected: $(if ($tier -eq 'full') { 'Full Install (Tier 1)' } else { 'Remote Only (Tier 2)' })" "OK"

    if ($tier -eq "full" -and -not $Env.HasUV) {
        Write-Host ""
        Write-Host "  uv is required for local installation." -ForegroundColor Yellow
        $installUV = Read-Host "  Install uv now? [Y/n]"

        if ($installUV -eq "n" -or $installUV -eq "N") {
            Write-Host "  Falling back to Tier 2 (remote only)." -ForegroundColor Yellow
            $tier = "remote"
        }
        else {
            Install-UV
            if (-not (Test-CommandExists "uv")) {
                Write-Host "  uv installation failed. Falling back to Tier 2." -ForegroundColor Yellow
                $tier = "remote"
            }
        }
    }

    return $tier
}

function Install-UV {
    Write-Step "Installing uv..." "..."
    try {
        if ($IsWindows) {
            Invoke-Expression "& { $(Invoke-RestMethod 'https://astral.sh/uv/install.ps1') }"
        }
        else {
            $installer = Invoke-RestMethod "https://astral.sh/uv/install.sh"
            $installer | & sh
        }

        # Refresh PATH
        if ($IsWindows) {
            $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        else {
            $env:PATH = "$HOME/.local/bin:$env:PATH"
        }

        Write-Step "uv installed" "OK"
    }
    catch {
        Write-Step "Failed to install uv: $_" "FAIL"
        Write-Host "  Visit https://docs.astral.sh/uv/ for manual installation." -ForegroundColor DarkGray
    }
}

# ─── Step 3: Authentication (Device Flow + Manual Fallback) ───────────────

function Get-AuthenticationManual {
    # Manual API key paste — fallback when device flow is unavailable
    Write-Host ""
    Write-Host "  Opening Jules.Solutions in your browser..." -ForegroundColor White
    Write-Host "  Sign up or log in, then copy your API key from the dashboard." -ForegroundColor DarkGray
    Write-Host ""

    $authUrl = $Script:Config.AuthURL

    try {
        switch (Get-OSName) {
            "windows" { Start-Process $authUrl }
            "macos"   { & open $authUrl }
            "linux"   { & xdg-open $authUrl 2>$null }
        }
        Write-Step "Browser opened: $authUrl" "OK"
    }
    catch {
        Write-Step "Could not open browser. Visit manually:" "SKIP"
        Write-Host "  $authUrl" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "  After logging in:" -ForegroundColor White
    Write-Host "    1. Go to the API Keys section" -ForegroundColor DarkGray
    Write-Host "    2. Create a new key (or copy an existing one)" -ForegroundColor DarkGray
    Write-Host "    3. It starts with 'dck_'" -ForegroundColor DarkGray
    Write-Host ""

    do {
        $apiKey = (Read-Host "  Paste your API key (dck_...)").Trim()
        if (-not $apiKey.StartsWith("dck_")) {
            Write-Host "  Key must start with 'dck_'. Try again." -ForegroundColor Red
        }
    } while (-not $apiKey.StartsWith("dck_"))

    # Verify
    Write-Step "Verifying API key..." "..."
    try {
        $headers = @{ "X-API-Key" = $apiKey }
        $response = Invoke-RestMethod -Uri "$($Script:Config.ApiURL)/health" -Headers $headers -TimeoutSec 10
        if ($response.status -in @("healthy", "ok")) {
            Write-Step "API key verified — connected to $($response.service)" "OK"
        }
        else {
            Write-Step "API responded with status: $($response.status)" "SKIP"
        }
    }
    catch {
        Write-Step "Could not verify key — continuing anyway" "SKIP"
    }

    return $apiKey
}

function Get-Authentication {
    Write-Header "Authentication"

    # Try device flow first
    Write-Step "Requesting device authorization..." "..."
    try {
        $response = Invoke-RestMethod -Uri "$($Script:Config.AuthURL)/api/auth/device/code" -Method POST -ContentType "application/json" -TimeoutSec 10
        $deviceCode = $response.device_code
        $userCode = $response.user_code
        $verifyUrl = $response.verification_uri
        $interval = [int]$response.interval
        $expiresIn = [int]$response.expires_in
    }
    catch {
        Write-Step "Device flow unavailable — using manual key entry" "SKIP"
        return Get-AuthenticationManual
    }

    # Show code
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |                                         |" -ForegroundColor Cyan
    Write-Host "  |   Your code:  $userCode              |" -ForegroundColor White
    Write-Host "  |                                         |" -ForegroundColor Cyan
    Write-Host "  +-----------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Opening browser... Enter this code to authorize." -ForegroundColor DarkGray
    Write-Host "  URL: $verifyUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        switch (Get-OSName) {
            "windows" { Start-Process $verifyUrl }
            "macos"   { & open $verifyUrl }
            "linux"   { & xdg-open $verifyUrl 2>$null }
        }
    }
    catch {
        Write-Step "Could not open browser. Visit: $verifyUrl" "SKIP"
    }

    # Poll for authorization
    Write-Step "Waiting for authorization..." "..."
    $deadline = (Get-Date).AddSeconds($expiresIn)
    $apiKey = $null

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $interval
        try {
            $poll = Invoke-RestMethod -Uri "$($Script:Config.AuthURL)/api/auth/device/token?device_code=$deviceCode" -TimeoutSec 10
            if ($poll.status -eq "complete") {
                $apiKey = $poll.api_key
                break
            }
            if ($poll.status -eq "expired") {
                break
            }
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        catch {
            # Network error — keep trying
        }
    }

    Write-Host ""

    if ($apiKey) {
        Write-Step "Authorized! API key received." "OK"
        return $apiKey
    }

    Write-Step "Authorization timed out." "FAIL"
    Write-Host "  Falling back to manual key entry..." -ForegroundColor Yellow
    return Get-AuthenticationManual
}

# ─── Step 4: Configure MCP ─────────────────────────────────────────────────

function Set-McpConfig {
    param([string]$ApiKey)

    Write-Header "MCP Configuration"

    $mcpPath = $Script:Config.McpJsonPath

    # Build new entry
    $julesServer = @{
        url     = $Script:Config.McpURL
        headers = @{ "X-API-Key" = $ApiKey }
    }

    # Read existing or create new
    $mcpConfig = @{ mcpServers = @{} }
    if (Test-Path $mcpPath) {
        try {
            $existing = Get-Content $mcpPath -Raw | ConvertFrom-Json -AsHashtable
            if ($existing -and $existing.ContainsKey("mcpServers")) {
                $mcpConfig = $existing
            }
            Write-Step "Found existing $mcpPath — merging" "OK"
        }
        catch {
            Write-Step "Existing file invalid — creating new" "SKIP"
        }
    }

    $mcpConfig.mcpServers["jules"] = $julesServer

    # Write
    $json = $mcpConfig | ConvertTo-Json -Depth 10
    Set-Content -Path $mcpPath -Value $json -Encoding UTF8
    Write-Step "Written: $mcpPath" "OK"
    Write-Host "    Server: $($Script:Config.McpURL)" -ForegroundColor DarkGray
}

# ─── Step 5: Install jules-local (Tier 1) ──────────────────────────────────

function Install-JulesLocal {
    Write-Header "Installing jules-local"

    Write-Step "Installing from GitHub via uv..." "..."
    try {
        $output = & uv tool install "git+$($Script:Config.LocalRepo)" 2>&1
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

        if ($LASTEXITCODE -eq 0) {
            Write-Step "jules-local installed" "OK"
            return $true
        }
        else {
            Write-Step "Install returned non-zero exit code" "FAIL"
            Write-Host "  Manual install: uv tool install git+$($Script:Config.LocalRepo)" -ForegroundColor DarkGray
            return $false
        }
    }
    catch {
        Write-Step "Failed: $_" "FAIL"
        Write-Host "  Manual install: uv tool install git+$($Script:Config.LocalRepo)" -ForegroundColor DarkGray
        return $false
    }
}

# ─── Step 6: Configure jules-local (Tier 1) ───────────────────────────────

function Set-LocalConfig {
    param([string]$ApiKey)

    Write-Header "Local Configuration"

    $configDir  = $Script:Config.ConfigDir
    $configPath = Join-Path $configDir "config.toml"

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $content = @"
# Jules.Solutions local configuration
# Generated by installer v$($Script:Config.Version) on $(Get-Date -Format "yyyy-MM-dd")

[auth]
api_key = "$ApiKey"
api_url = "$($Script:Config.ApiURL)"

[local]
vault_path = ""  # Set to your vault directory
"@

    if (Test-Path $configPath) {
        Write-Step "Config already exists: $configPath" "SKIP"
        $overwrite = Read-Host "  Overwrite? [y/N]"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-Step "Kept existing config" "SKIP"
            return
        }
    }

    Set-Content -Path $configPath -Value $content -Encoding UTF8
    Write-Step "Written: $configPath" "OK"
}

# ─── Step 7: Verification ──────────────────────────────────────────────────

function Test-Installation {
    param([string]$Tier, [string]$ApiKey)

    Write-Header "Verification"

    $pass = $true

    # API
    try {
        $r = Invoke-RestMethod -Uri "$($Script:Config.ApiURL)/health" -Headers @{ "X-API-Key" = $ApiKey } -TimeoutSec 10
        Write-Step "API: $($r.status)" "OK"
    }
    catch {
        Write-Step "API: unreachable" "FAIL"
        $pass = $false
    }

    # Auth
    try {
        $r = Invoke-RestMethod -Uri "$($Script:Config.AuthURL)/api/auth/ok" -TimeoutSec 10
        Write-Step "Auth: $(if ($r.ok) { 'healthy' } else { 'unknown' })" "OK"
    }
    catch {
        Write-Step "Auth: unreachable" "FAIL"
        $pass = $false
    }

    # MCP config
    if (Test-Path $Script:Config.McpJsonPath) {
        Write-Step "MCP config: exists" "OK"
    }
    else {
        Write-Step "MCP config: missing" "FAIL"
        $pass = $false
    }

    # Tier 1 extras
    if ($Tier -eq "full") {
        if (Test-CommandExists "jules") {
            Write-Step "jules CLI: found" "OK"
        }
        else {
            Write-Step "jules CLI: not in PATH (restart shell)" "SKIP"
        }

        $cfgPath = Join-Path $Script:Config.ConfigDir "config.toml"
        if (Test-Path $cfgPath) {
            Write-Step "Local config: exists" "OK"
        }
        else {
            Write-Step "Local config: missing" "FAIL"
            $pass = $false
        }
    }

    return $pass
}

# ─── Step 8: Completion ────────────────────────────────────────────────────

function Show-Completion {
    param([string]$Tier, [bool]$AllGood)

    Write-Host ""
    if ($AllGood) {
        Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║          Setup Complete!                      ║" -ForegroundColor Green
        Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Green
    }
    else {
        Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "  ║     Setup completed with warnings.            ║" -ForegroundColor Yellow
        Write-Host "  ║     Review items marked [!] above.            ║" -ForegroundColor Yellow
        Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Restart Claude Code (or your terminal)" -ForegroundColor Cyan
    Write-Host "     The MCP server 'jules' will appear in your tools." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Try it:" -ForegroundColor Cyan
    Write-Host '     claude> "Use the jules MCP tools to list my tasks"' -ForegroundColor DarkGray

    if ($Tier -eq "full") {
        Write-Host ""
        Write-Host "  3. Start local server (optional):" -ForegroundColor Cyan
        Write-Host "     jules serve --vault ~/your-vault" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  Dashboard:  https://app.jules.solutions" -ForegroundColor DarkGray
    Write-Host "  Docs:       https://jules.solutions/docs" -ForegroundColor DarkGray
    Write-Host "  Support:    https://github.com/Jules-Solutions/installer/issues" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Main ───────────────────────────────────────────────────────────────────

function Main {
    Show-Banner

    $detected = Get-Environment
    $tier     = Select-Tier -Env $detected
    $apiKey   = Get-Authentication

    Set-McpConfig -ApiKey $apiKey

    if ($tier -eq "full") {
        $ok = Install-JulesLocal
        if ($ok) { Set-LocalConfig -ApiKey $apiKey }
    }

    $allGood = Test-Installation -Tier $tier -ApiKey $apiKey
    Show-Completion -Tier $tier -AllGood $allGood
}

Main
