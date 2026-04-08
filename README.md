# Jules.Solutions Platform Installer

One command to connect to the Jules.Solutions AI platform.

## Quick Start

### Windows (PowerShell 7+)

```powershell
irm https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1 | pwsh -
```

> **Requires:** [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (cross-platform)

## What It Does

The installer walks you through connecting to the Jules.Solutions platform:

1. **Detects** your environment (OS, Claude Code, uv, Python)
2. **Asks** which tier you want:
   - **Tier 1 (Full):** Local runtime + remote MCP connection
   - **Tier 2 (Remote):** MCP connection only
3. **Authenticates** you via [auth.jules.solutions](https://auth.jules.solutions)
4. **Configures** your `.mcp.json` with the Jules MCP server
5. **Installs** `jules-local` (Tier 1 only, via [uv](https://docs.astral.sh/uv/))
6. **Verifies** everything works

After setup, restart Claude Code. The `jules` MCP server appears in your tools.

## Installation Tiers

| Tier | What You Get | Requirements |
|------|-------------|-------------|
| **Full (Tier 1)** | Local runtime + MCP tools + CLI | Python + uv (installer helps install uv) |
| **Remote (Tier 2)** | MCP tools only (via SSE) | Nothing (just PowerShell) |

## What Gets Created

| File | Purpose |
|------|---------|
| `~/.mcp.json` | MCP server configuration (jules server entry) |
| `~/.config/devcli/config.toml` | Local runtime config (Tier 1 only) |

## Architecture

```
User runs install.ps1
     |
     v
[1] Environment detection (OS, tools)
     |
     v
[2] Tier selection (Full or Remote)
     |
     v
[3] Auth (browser -> auth.jules.solutions -> API key)
     |
     v
[4] Write .mcp.json (MCP SSE connection)
     |
     +-- Tier 2: Done!
     |
     v  (Tier 1 only)
[5] Install jules-local (uv tool install)
     |
     v
[6] Write config.toml
     |
     v
[7] Verify all connections
```

## Platform Services

| Service | URL | What |
|---------|-----|------|
| API | api.jules.solutions | Platform backbone (tasks, projects, goals, sessions) |
| Auth | auth.jules.solutions | Identity, login, API keys |
| Dashboard | app.jules.solutions | Web UI for the platform |
| MCP | mcp.jules.solutions | Model Context Protocol endpoint |

## Development

```
installer/
├── install.ps1                  # Self-contained installer script
├── apps/registry.json           # App catalog metadata
├── manifests/jules-platform.json # Installation manifest
├── docs/MANIFEST_SPEC.md        # Manifest specification
└── README.md
```

The installer is a single self-contained PowerShell script. No build step, no dependencies.

### Testing

```powershell
# Syntax check
pwsh -Command "& { $null = [System.Management.Automation.Language.Parser]::ParseFile('install.ps1', [ref]$null, [ref]$null) }"

# Dry run (will open browser for auth)
pwsh ./install.ps1
```

## Legacy

Previous versions supported DevCLI and TotallyLegal installations via GitHub auth and a WPF GUI installer. Those have been replaced by the platform installer. See git history for the old version.

## Links

- [Jules.Solutions](https://jules.solutions)
- [Platform Dashboard](https://app.jules.solutions)
- [Auth Service](https://auth.jules.solutions)
- [jules-local](https://github.com/Jules-Solutions/jules-local)
