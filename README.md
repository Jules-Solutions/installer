# Jules.Solutions Installer

One-click installer for Jules.Solutions applications (DevCLI, TotallyLegal, and more).

## Architecture

**Public bootstrap installer** → GitHub auth → **Private installer (DevCLI)**

This solves the code signing problem: the public bootstrap is simple enough to avoid antivirus flags, while the real installation is secured behind GitHub authentication.

## Files

### One-Click Installer (NEW!)

**`dist/Jules.Solutions-Installer.exe`** - Standalone Windows executable
- Size: ~147MB (includes .NET runtime)
- Icon: Jules.Solutions logo embedded
- Requirements: Windows x64 only (no dependencies!)
- Source: `src/Installer.cs` + `src/logo.ico`

**How it works:**
1. User downloads `Jules.Solutions-Installer.exe`
2. Double-clicks it
3. It runs: `irm install.ps1 | iex` from GitHub
4. install.ps1 handles the rest (gh CLI, auth, real installer)

### PowerShell Bootstrap

**`install.ps1`** - Public PowerShell bootstrap script
- Hosted on GitHub: `https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1`
- Installs GitHub CLI if needed
- Prompts for GitHub authentication
- Downloads `Install-GUI.ps1` from private Jul352mf/DevCLI repo
- Launches the GUI installer

**`Install.bat`** - Legacy batch file wrapper
- Runs `irm install.ps1 | iex`
- Still works, but .exe is preferred

## Building the One-Click Installer

### Prerequisites
- .NET 8.0 SDK or later
- Logo file at `src/logo.ico`

### Build Commands

**Quick build (requires .NET runtime on target machine):**
```bash
cd src
dotnet build -c Release -o ../dist
```

**Standalone build (works on any Windows x64, no .NET needed):**
```bash
cd src
dotnet publish -c Release -o ../dist
```

This creates `dist/Jules.Solutions-Installer.exe` ready to distribute!

### Build Script

Use the PowerShell build script:
```powershell
.\Build-Installer.ps1
```

## Development

**Edit the installer:**
- Modify `src/Installer.cs`
- Update `src/Installer.csproj` if needed
- Rebuild with `dotnet publish`

**Update the logo:**
- Replace `src/logo.ico`
- Rebuild

## Distribution

1. Build: `cd src && dotnet publish -c Release -o ../dist`
2. Test: Run `dist/Jules.Solutions-Installer.exe` locally
3. Upload to your distribution server or GitHub releases
4. Share download link with users

## How the Full Flow Works

```
User downloads Jules.Solutions-Installer.exe
         ↓
    Double-click
         ↓
Runs: irm install.ps1 | iex (from GitHub)
         ↓
App selection menu: DevCLI or TotallyLegal
         ↓
    [DevCLI path]              [TotallyLegal path]
install.ps1 installs gh CLI    Downloads Install-TotallyLegal.ps1
         ↓                              ↓
Browser opens for GitHub login  Auto-detects BAR installation
         ↓                              ↓
Downloads Install-GUI.ps1       Downloads widgets from GitHub
(from private repo)                      ↓
         ↓                     Copies to BAR/LuaUI/Widgets/
WPF GUI installer launches              ↓
         ↓                     Done! Launch BAR and enable widgets
DevCLI + {Name}.Life vault
installed
```

## Supported Applications

| App | Repo | Type | Description |
|-----|------|------|-------------|
| DevCLI | Jul352mf/DevCLI | Private | AI-powered development assistant |
| TotallyLegal | Jules-Solutions/Open-BAR | Public | Beyond All Reason widget suite |

## Related Repos

- [Jules-Solutions/installer](https://github.com/Jules-Solutions/installer) - This repo (public bootstrap)
- [Jul352mf/DevCLI](https://github.com/Jul352mf/DevCLI) - Private application repo
- [Jules-Solutions/Open-BAR](https://github.com/Jules-Solutions/Open-BAR) - TotallyLegal widgets (public)
