# Changelog, WorkplaceAssessment

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

---

## [1.0.0] - 2026-07-10

### Added

- Initial public release of the assessment engine (internally versioned "V14")
- Ten checks across four categories (security, health, storage, management): reboot-pending, uptime, battery health, system-drive free space, local administrators, remote-access tools, Windows edition & license activation, autostart entries, Secure Boot, TPM 2.0
- Self-contained HTML report with embedded JSON, filterable/searchable findings table, and per-category score breakdown
- `Start-Assessment-v14.cmd` launcher with automatic UAC elevation, so the TPM check produces real data by default

### Fixed

- The internal `Finding` helper used a parameter literally named `$args`, which collided with PowerShell's automatic `$args` variable. As a result, every evidence-text placeholder (e.g. `{freeGb}`, `{count}`, `{days}`) across *all* checks was silently never substituted. Renamed the parameter to `$eArgs`; all evidence text now renders with real values.

[1.0.0]: https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases/tag/v1.0.0
