# download.ps1 - File download helpers for GitHub repos

function Get-GitHubFileContent {
    <#
    .SYNOPSIS
        Download a file from a GitHub repository using gh CLI
    .PARAMETER Repo
        Repository in owner/repo format
    .PARAMETER Path
        Path to file within the repo
    .PARAMETER Branch
        Branch name (default: main or master)
    .OUTPUTS
        File content as string, or $null on failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Branch
    )
    
    # Try to get content via gh api
    $content = gh api "repos/$Repo/contents/$Path" --jq '.content' 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Verbose "Failed to download $Path from $Repo"
        return $null
    }
    
    # Decode base64
    try {
        $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content))
        return $decoded
    }
    catch {
        Write-Verbose "Failed to decode content: $_"
        return $null
    }
}

function Get-GitHubJsonFile {
    <#
    .SYNOPSIS
        Download and parse a JSON file from a GitHub repository
    .OUTPUTS
        Parsed object, or $null on failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $content = Get-GitHubFileContent -Repo $Repo -Path $Path
    
    if (-not $content) {
        return $null
    }
    
    try {
        return $content | ConvertFrom-Json
    }
    catch {
        Write-Verbose "Failed to parse JSON from $Path`: $_"
        return $null
    }
}

function Save-GitHubFile {
    <#
    .SYNOPSIS
        Download a file from GitHub and save to local path
    .OUTPUTS
        $true on success, $false on failure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter(Mandatory)]
        [string]$RemotePath,
        
        [Parameter(Mandatory)]
        [string]$LocalPath
    )
    
    $content = Get-GitHubFileContent -Repo $Repo -Path $RemotePath
    
    if (-not $content) {
        return $false
    }
    
    # Ensure directory exists
    $dir = Split-Path $LocalPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    Set-Content -Path $LocalPath -Value $content -Encoding UTF8
    return $true
}

function Test-RepoAccessible {
    <#
    .SYNOPSIS
        Check if a repository is accessible (exists and user has permission)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo
    )
    
    $null = gh api "repos/$Repo" 2>&1
    return $LASTEXITCODE -eq 0
}
