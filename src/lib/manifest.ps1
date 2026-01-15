# manifest.ps1 - App manifest parser and executor

function Get-AppManifest {
    <#
    .SYNOPSIS
        Download and parse an app's install manifest
    .PARAMETER Repo
        Repository in owner/repo format
    .PARAMETER ManifestPath
        Path to manifest.json within repo (default: install/manifest.json)
    .OUTPUTS
        Parsed manifest object with defaults applied
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [string]$ManifestPath = "install/manifest.json"
    )
    
    . "$PSScriptRoot\download.ps1"
    
    $manifest = Get-GitHubJsonFile -Repo $Repo -Path $ManifestPath
    
    if (-not $manifest) {
        throw "Failed to download manifest from $Repo/$ManifestPath"
    }
    
    # Apply defaults
    if (-not $manifest.PSObject.Properties['requirements']) {
        $manifest | Add-Member -NotePropertyName 'requirements' -NotePropertyValue @{
            os = "windows"
            minPowershell = "5.1"
        }
    }
    
    if (-not $manifest.PSObject.Properties['variables']) {
        $manifest | Add-Member -NotePropertyName 'variables' -NotePropertyValue @{}
    }
    
    if (-not $manifest.PSObject.Properties['options']) {
        $manifest | Add-Member -NotePropertyName 'options' -NotePropertyValue @()
    }
    
    if (-not $manifest.PSObject.Properties['steps']) {
        $manifest | Add-Member -NotePropertyName 'steps' -NotePropertyValue @()
    }
    
    return $manifest
}

function Resolve-ManifestVariables {
    <#
    .SYNOPSIS
        Resolve variable references in a string
    .PARAMETER Template
        String containing ${variableName} references
    .PARAMETER Variables
        Hashtable of variable values
    .OUTPUTS
        String with variables replaced
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [Parameter(Mandatory)]
        [hashtable]$Variables
    )
    
    $result = $Template
    
    foreach ($key in $Variables.Keys) {
        $result = $result -replace "\`$\{$key\}", $Variables[$key]
    }
    
    # Handle $env: references
    $result = $result -replace '\$env:(\w+)', { $env:($matches[1]) }
    
    return $result
}

function Test-StepCondition {
    <#
    .SYNOPSIS
        Evaluate a step's condition expression
    .PARAMETER Condition
        Condition string (e.g., "true", "${option}", "${a} == 'full'")
    .PARAMETER Variables
        Hashtable of variable/option values
    .OUTPUTS
        $true if condition passes, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [string]$Condition,
        
        [hashtable]$Variables
    )
    
    if ([string]::IsNullOrEmpty($Condition)) {
        return $true
    }
    
    # Replace variables
    $expr = Resolve-ManifestVariables -Template $Condition -Variables $Variables
    
    # Handle simple boolean
    if ($expr -eq 'true' -or $expr -eq 'True' -or $expr -eq '$true') {
        return $true
    }
    if ($expr -eq 'false' -or $expr -eq 'False' -or $expr -eq '$false') {
        return $false
    }
    
    # Try to evaluate as PowerShell expression
    try {
        $result = Invoke-Expression $expr
        return [bool]$result
    }
    catch {
        Write-Verbose "Failed to evaluate condition '$Condition': $_"
        return $true  # Default to running the step
    }
}

function Get-StepArguments {
    <#
    .SYNOPSIS
        Build argument array for a step script
    .PARAMETER Args
        Array of argument strings/templates
    .PARAMETER Variables
        Hashtable of variable values
    .OUTPUTS
        Array of resolved arguments
    #>
    [CmdletBinding()]
    param(
        [array]$Args,
        
        [hashtable]$Variables
    )
    
    if (-not $Args) {
        return @()
    }
    
    $resolved = @()
    foreach ($arg in $Args) {
        $resolved += Resolve-ManifestVariables -Template $arg -Variables $Variables
    }
    
    return $resolved
}

function Get-ManifestDefaults {
    <#
    .SYNOPSIS
        Extract default values from manifest variables and options
    .OUTPUTS
        Hashtable of variable/option names to default values
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest
    )
    
    $defaults = @{}
    
    # Variables
    if ($Manifest.variables) {
        $Manifest.variables.PSObject.Properties | ForEach-Object {
            $varDef = $_.Value
            $default = $varDef.default
            
            # Expand $env: references in defaults
            if ($default -match '^\$env:(\w+)$') {
                $default = [Environment]::GetEnvironmentVariable($matches[1])
            }
            
            $defaults[$_.Name] = $default
        }
    }
    
    # Options
    if ($Manifest.options) {
        foreach ($opt in $Manifest.options) {
            $defaults[$opt.id] = $opt.default
        }
    }
    
    return $defaults
}
