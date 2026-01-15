# Jules.Solutions Installer

Generic installer framework for Jules.Solutions applications.

## Architecture

```
installer/
├── Install.bat              # Drop-anywhere entry point
├── install.ps1              # Public bootstrapper (downloaded by users)
├── src/
│   ├── Invoke-Installer.ps1 # Main installer orchestrator
│   ├── gui/
│   │   ├── Install-GUI.ps1  # Generic WPF GUI framework
│   │   └── themes/
│   │       └── dark.xaml    # UI theme definitions
│   └── lib/
│       ├── auth.ps1         # GitHub authentication helpers
│       ├── download.ps1     # File download helpers
│       └── manifest.ps1     # App manifest parser
├── apps/                    # App registry (lightweight references)
│   └── devcli.json          # Points to Jul352mf/DevCLI
└── docs/
    └── MANIFEST_SPEC.md     # How to create app manifests
```

## How It Works

1. User runs `irm .../install.ps1 | iex`
2. Installer authenticates with GitHub (if needed for private apps)
3. Downloads app manifest from the app's repo
4. GUI renders pages/options defined in manifest
5. Executes installation steps defined in manifest

## App Integration

Apps provide their own `install/manifest.json`:

```json
{
  "name": "DevCLI",
  "version": "0.1.0",
  "description": "AI-powered development assistant",
  "private": true,
  "options": [...],
  "steps": [...]
}
```

See [MANIFEST_SPEC.md](docs/MANIFEST_SPEC.md) for full specification.

## Development

```powershell
# Test locally
.\src\Invoke-Installer.ps1 -App devcli

# Build release
.\Build-Release.ps1
```

## Related Repos

- [Jul352mf/DevCLI](https://github.com/Jul352mf/DevCLI) - DevCLI application
- [Jules-Solutions/installer](https://github.com/Jules-Solutions/installer) - Public installer (this repo's deployment target)
