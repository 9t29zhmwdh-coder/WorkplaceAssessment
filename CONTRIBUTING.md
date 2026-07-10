# Contributing to WorkplaceAssessment

## Getting Started

### Prerequisites

- Windows 10 or 11
- PowerShell 5.1+ (built into Windows) or PowerShell 7+

There is nothing to install and no build step — the script runs as-is.

### Setup

1. Fork the repository
2. `git clone https://github.com/YOUR_USERNAME/WorkplaceAssessment`
3. `cd WorkplaceAssessment`
4. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessmentV14.ps1 -NoOpen`

## Development Workflow

1. Create a feature branch: `git checkout -b feature/xyz`
2. Make your changes to `scripts/Invoke-WorkplaceAssessmentV14.ps1`
3. Validate syntax:
   ```powershell
   $errors = $null; $tokens = $null
   [System.Management.Automation.Language.Parser]::ParseFile('scripts\Invoke-WorkplaceAssessmentV14.ps1', [ref]$tokens, [ref]$errors) | Out-Null
   $errors
   ```
4. Run the script and confirm the JSON/HTML report generates correctly, including your change
5. Commit: `git commit -m "[feat] description"`
6. Push and open a Pull Request

## Code Style

- Follow the existing compact style: each check is a single self-contained function using the `Finding` helper (see [ARCHITECTURE.md](ARCHITECTURE.md))
- Every WMI/CIM/registry query must be wrapped in `try`/`catch` and degrade to `info`/`0`/`0` on failure — never let one check crash the whole run
- New evidence/risk/recommendation text goes into the `const T = {...}` dictionary in the HTML template, using the same `key:'text with {placeholder}'` format as existing entries
- Do not add network calls, telemetry, or external module dependencies — see [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md)

## Commit Convention

`[type] description` — where type is:
- `[feat]` — new feature (e.g. a new check)
- `[fix]` — bug fix
- `[docs]` — documentation only
- `[refactor]` — code cleanup
- `[test]` — tests only

## Questions?

Open an issue or discussion on GitHub.
