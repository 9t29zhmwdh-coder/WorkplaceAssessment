# Contributing to WorkplaceAssessment

## Getting Started

### Prerequisites

- Windows 10 or 11
- PowerShell 5.1+ (built into Windows) or PowerShell 7+
- [Inno Setup 6](https://jrsoftware.org/isdl.php): only needed if you're changing `installer/WorkplaceAssessment.iss`; not required for script changes

There is nothing to install and no build step for the script itself; it runs as-is.

### Setup

1. Fork the repository
2. `git clone https://github.com/YOUR_USERNAME/WorkplaceAssessment`
3. `cd WorkplaceAssessment`
4. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessment.ps1 -NoOpen`

## Development Workflow

1. Create a feature branch: `git checkout -b feature/xyz`
2. Make your changes to `scripts/Invoke-WorkplaceAssessment.ps1`
3. Validate syntax:
   ```powershell
   $errors = $null; $tokens = $null
   [System.Management.Automation.Language.Parser]::ParseFile('scripts\Invoke-WorkplaceAssessment.ps1', [ref]$tokens, [ref]$errors) | Out-Null
   $errors
   ```
4. Run the script and confirm the JSON/HTML report generates correctly, including your change
5. Commit: `git commit -m "[feat] description"`
6. Push and open a Pull Request

## Changing the Installer

`installer/WorkplaceAssessment.iss` is only compiled by CI (`.github/workflows/release.yml`) on a version tag push or via manual `workflow_dispatch`; there's no need to have Inno Setup installed unless you're editing that file directly. To test a change locally:

```powershell
iscc /DMyAppVersion=0.0.0-test installer\WorkplaceAssessment.iss
```

This produces `dist\WorkplaceAssessment-Setup-0.0.0-test.exe`. Run it in a VM or with a throwaway user profile before relying on it, since it installs to Program Files and creates real Start Menu/registry entries.

## Code Style

- Follow the existing compact style: each check is a single self-contained function using the `Finding` helper (see [ARCHITECTURE.md](ARCHITECTURE.md))
- Every WMI/CIM/registry query must be wrapped in `try`/`catch` and degrade to `info`/`0`/`0` on failure; never let one check crash the whole run
- New evidence/risk/recommendation text goes into the `const T = {...}` dictionary in the HTML template, using the same `key:'text with {placeholder}'` format as existing entries
- Do not add network calls, telemetry, or external module dependencies: see [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md)

## Commit Convention

`[type] description`, where type is:
- `[feat]`: new feature (e.g. a new check)
- `[fix]`: bug fix
- `[docs]`: documentation only
- `[refactor]`: code cleanup
- `[test]`: tests only

## Questions?

Open an issue or discussion on GitHub.
