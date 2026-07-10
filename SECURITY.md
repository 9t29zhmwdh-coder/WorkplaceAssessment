# Security Policy — WorkplaceAssessment

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

- No external network calls of any kind — the script never sends data anywhere, not even to `localhost`
- No modules or dependencies are downloaded at runtime; everything ships in one `.ps1` file
- No admin rights required for the baseline scan; the two checks that need elevation (TPM, battery-wear detail) degrade to "not scored" instead of failing or producing a false result when run unelevated
- `Start-Assessment-v14.cmd` requests UAC elevation via the standard Windows consent prompt (`Start-Process -Verb RunAs`) — it never silently escalates privileges
- Read-only by design: every check only queries system state (registry reads, WMI/CIM queries, cmdlets); nothing is modified on the scanned machine

## Data Sensitivity

Generated reports (`output/*.json`, `output/*.html`) contain machine-identifying and account data from the scanned device: hostname, logged-in username, local administrator group membership, installed remote-access tools, and a partial Windows product key. Treat exported reports as internal data — see [PRIVACY.md](PRIVACY.md) for details. This repository's `.gitignore` excludes `output/` for exactly this reason; never commit generated reports.

**Last updated: 2026-07-10**
