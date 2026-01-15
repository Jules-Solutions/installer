# auth.ps1 - GitHub authentication helpers

function Test-GitHubAuth {
    <#
    .SYNOPSIS
        Check if user is authenticated with GitHub CLI
    #>
    $null = gh auth status 2>&1
    return $LASTEXITCODE -eq 0
}

function Install-GitHubCLI {
    <#
    .SYNOPSIS
        Install GitHub CLI via winget if not present
    .OUTPUTS
        $true if gh is available after function completes
    #>
    [CmdletBinding()]
    param()
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Verbose "GitHub CLI already installed"
        return $true
    }
    
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [ERROR] winget not found. Please install GitHub CLI manually." -ForegroundColor Red
        return $false
    }
    
    $null = winget install GitHub.cli --accept-source-agreements --accept-package-agreements 2>&1
    
    # Refresh PATH
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + 
                [Environment]::GetEnvironmentVariable('PATH', 'User')
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] GitHub CLI installed" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  [ERROR] GitHub CLI installation failed" -ForegroundColor Red
    return $false
}

function Invoke-GitHubAuth {
    <#
    .SYNOPSIS
        Prompt user to authenticate with GitHub
    .OUTPUTS
        $true if authentication succeeds
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    
    if (Test-GitHubAuth) {
        Write-Verbose "Already authenticated"
        return $true
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  GitHub authentication required." -ForegroundColor Yellow
        Write-Host "  A browser window will open for login." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Press Enter to continue..." -ForegroundColor Cyan
        $null = Read-Host
    }
    
    # Use Start-Process to allow browser interaction
    Start-Process -FilePath "gh" -ArgumentList "auth", "login", "--web", "-h", "github.com", "-p", "https" -Wait -NoNewWindow
    
    if (Test-GitHubAuth) {
        Write-Host "  [OK] Authenticated" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  [ERROR] Authentication failed" -ForegroundColor Red
    return $false
}

function Get-GitHubUser {
    <#
    .SYNOPSIS
        Get the authenticated GitHub username
    #>
    if (-not (Test-GitHubAuth)) {
        return $null
    }
    
    $user = gh api user --jq '.login' 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $user
    }
    return $null
}
