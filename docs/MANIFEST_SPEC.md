# App Manifest Specification

Apps integrate with the Jules.Solutions installer by providing a manifest file at `install/manifest.json` in their repository.

## Manifest Schema

```json
{
  "$schema": "https://jules.solutions/schemas/install-manifest-v1.json",
  "name": "AppName",
  "version": "1.0.0",
  "description": "Short description shown in installer",
  "private": true,
  "repo": "owner/repo",
  
  "requirements": {
    "os": "windows",
    "minPowershell": "5.1",
    "tools": ["git", "gh"]
  },
  
  "variables": {
    "vaultName": {
      "type": "string",
      "prompt": "Your Name",
      "default": "$env:USERNAME",
      "description": "Used to create your personal vault",
      "validation": "^[^\\/:*?\"<>|]+$"
    }
  },
  
  "options": [
    {
      "id": "installType",
      "type": "radio",
      "label": "Installation Type",
      "choices": [
        {"value": "full", "label": "Full Installation", "description": "All features"},
        {"value": "minimal", "label": "Minimal", "description": "Core only"}
      ],
      "default": "full"
    },
    {
      "id": "setupObsidian",
      "type": "checkbox",
      "label": "Configure Obsidian",
      "default": true
    }
  ],
  
  "steps": [
    {
      "id": "deps",
      "name": "Installing dependencies",
      "script": "install/steps/01-deps.ps1",
      "args": ["-VaultName", "${vaultName}"],
      "condition": "true"
    },
    {
      "id": "vault",
      "name": "Setting up vault",
      "script": "install/steps/02-vault.ps1",
      "args": ["-VaultName", "${vaultName}"]
    },
    {
      "id": "obsidian",
      "name": "Configuring Obsidian",
      "script": "install/steps/03-obsidian.ps1",
      "condition": "${setupObsidian}"
    }
  ],
  
  "completion": {
    "message": "Installation complete!",
    "actions": [
      {
        "label": "Open terminal with DevCLI",
        "command": "powershell",
        "args": ["-NoExit", "-Command", "devcli status"],
        "default": true
      }
    ]
  }
}
```

## Field Reference

### Top Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Display name |
| version | string | Yes | Semver version |
| description | string | Yes | Short description for UI |
| private | boolean | No | If true, requires GitHub auth |
| repo | string | Yes | GitHub repo (owner/repo) |

### Variables

User-provided values collected before installation.

| Property | Type | Description |
|----------|------|-------------|
| type | string | `string`, `boolean`, `choice` |
| prompt | string | Label shown to user |
| default | string | Default value (can use $env:VAR) |
| validation | string | Regex pattern for validation |

### Options

Additional configuration shown on install type page.

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier |
| type | string | `radio`, `checkbox` |
| label | string | Display label |
| choices | array | For radio: list of {value, label, description} |
| default | any | Default value |

### Steps

Installation steps executed in order.

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier |
| name | string | Status message shown during install |
| script | string | Path to PowerShell script (relative to repo root) |
| args | array | Arguments to pass (supports ${variable} interpolation) |
| condition | string | Boolean expression (supports ${option} interpolation) |

### Completion

Post-installation configuration.

| Property | Type | Description |
|----------|------|-------------|
| message | string | Success message |
| actions | array | Optional actions user can take |

## Variable Interpolation

Use `${variableName}` to reference:
- Variables defined in `variables`
- Options defined in `options`
- Built-in variables: `${repo}`, `${version}`, `${installDir}`

## Conditions

Conditions support:
- Boolean literals: `true`, `false`
- Variable references: `${optionId}`
- Comparisons: `${installType} == 'full'`
- Logical operators: `${a} && ${b}`, `${a} || ${b}`, `!${a}`
