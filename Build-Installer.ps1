# Build Jules.Solutions One-Click Installer
# Creates Installer.exe with embedded logo

param(
    [string]$OutputName = "Jules.Solutions-Installer.exe"
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "      Building Jules.Solutions Installer" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# Find C# compiler
$csc = $null
$frameworkPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319"
if (Test-Path "$frameworkPath\csc.exe") {
    $csc = "$frameworkPath\csc.exe"
} else {
    # Try to find via vswhere (if Visual Studio installed)
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -property installationPath
        $csc = "$vsPath\MSBuild\Current\Bin\Roslyn\csc.exe"
    }
}

if (-not $csc -or -not (Test-Path $csc)) {
    Write-Host "  [ERROR] C# compiler not found!" -ForegroundColor Red
    Write-Host "  Install .NET Framework 4.0+ or Visual Studio" -ForegroundColor Yellow
    exit 1
}

Write-Host "  [OK] Found C# compiler: $csc" -ForegroundColor Green

# Check source files exist
if (-not (Test-Path "src\Installer.cs")) {
    Write-Host "  [ERROR] src\Installer.cs not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "src\logo.ico")) {
    Write-Host "  [ERROR] src\logo.ico not found!" -ForegroundColor Red
    exit 1
}

# Build the installer
Write-Host ""
Write-Host "  Compiling installer..." -ForegroundColor Gray

$outputDir = "dist"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$outputPath = Join-Path $outputDir $OutputName

& $csc `
    /target:winexe `
    /win32icon:"src\logo.ico" `
    /out:"$outputPath" `
    /reference:System.Windows.Forms.dll `
    /reference:System.Drawing.dll `
    src\Installer.cs

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Compilation failed!" -ForegroundColor Red
    exit 1
}

# Check output
if (Test-Path $outputPath) {
    $size = (Get-Item $outputPath).Length
    $sizeKB = [math]::Round($size / 1KB, 1)
    
    Write-Host "  [OK] Compiled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Output: $outputPath" -ForegroundColor Cyan
    Write-Host "  Size:   $sizeKB KB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Ready to distribute!" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Output file not created!" -ForegroundColor Red
    exit 1
}

Write-Host ""
