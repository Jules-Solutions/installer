# Jules.Solutions Installer

One-click installer for Jules.Solutions apps.

## Quick Install

**Option 1: Download and double-click**
1. Download [Install.bat](https://raw.githubusercontent.com/Jules-Solutions/installer/main/Install.bat)
2. Double-click it
3. Done!

**Option 2: PowerShell one-liner**
```powershell
irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex
```

## What Gets Installed

- **DevCLI** - AI-powered development assistant
- **Your .Life vault** - Personal knowledge management

## How It Works

1. Installer downloads from this public repo
2. If the app is private, you'll be prompted to authenticate with GitHub
3. App-specific installer runs and sets everything up

## Requirements

- Windows 10/11
- PowerShell 5.1+ (included with Windows)
- GitHub account (for private apps)

## For Developers

Apps are defined in `install.ps1`. To add a new app:

```powershell
$Apps = @{
    "YourApp" = @{
        Repo = "org/repo"
        Description = "What it does"
        Private = $true  # or $false for public repos
        Bootstrap = "path/to/install-script.ps1"
    }
}
```

---

[Jules.Solutions](https://github.com/Jules-Solutions)
