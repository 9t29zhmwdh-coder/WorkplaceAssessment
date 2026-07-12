# Security Policy: WorkplaceAssessment

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅        |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report via [GitHub Security Advisory](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/security/advisories/new)
or contact the maintainer via the GitHub profile.

Include: description, steps to reproduce, potential impact, suggested fix.
Response within 7 days.

## Security Design

- No external network calls of any kind: the script never sends data anywhere, not even to `localhost`
- No modules or dependencies are downloaded at runtime; everything ships in one `.ps1` file
- No admin rights required for the baseline scan; the two checks that need elevation (TPM, battery-wear detail) degrade to "not scored" instead of failing or producing a false result when run unelevated
- `Start-Assessment.cmd` requests UAC elevation via the standard Windows consent prompt (`Start-Process -Verb RunAs`); it never silently escalates privileges
- Read-only by design: every check only queries system state (registry reads, WMI/CIM queries, cmdlets); nothing is modified on the scanned machine

## Installer

`WorkplaceAssessment-Setup-*.exe` is built by CI from `installer/WorkplaceAssessment.iss` (Inno Setup) and published as a GitHub Release asset. It is not code-signed. Windows SmartScreen may warn on first run of an unsigned executable; verify you downloaded it from this repository's [Releases page](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases) before proceeding past that warning. The installer itself requires admin rights (it writes to Program Files), but installing it does not change the script's own elevation behavior described above.

## Data Sensitivity

Generated reports (`output/*.json`, `output/*.html`) contain machine-identifying and account data from the scanned device: hostname, logged-in username, local administrator group membership, installed remote-access tools, and a partial Windows product key. Treat exported reports as internal data: see [PRIVACY.md](PRIVACY.md) for details. This repository's `.gitignore` excludes `output/` for exactly this reason; never commit generated reports.

**Last updated: 2026-07-10**
