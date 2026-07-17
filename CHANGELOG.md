# Changelog, WorkplaceAssessment

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

---

## [Unreleased] - 2026-07-17

### Changed
- CI: added an explicit `permissions: contents: read` block to the workflow(s) that were missing one (CodeQL `actions/missing-workflow-permissions`), narrowing the default GITHUB_TOKEN scope.

## [1.1.0] - 2026-07-13

### Added

- `scripts/Compare-WorkplaceAssessment.ps1`: historical trend comparison between two JSON reports for the same device. Diffs every check by score/status and tags it `improved`, `regressed`, `new`, or `removed`; prints an overall-score delta and a console table of everything that changed. `-OutJson` saves the comparison for scripted or ticketing-system use. Closes the historical-trend blocker in this repo's Dual-Licensing Readiness assessment (ROADMAP.md); fleet batch mode/CSV export and English localization remain open.

## [1.0.4] - 2026-07-12

### Fixed

- Removed em-dashes/en-dashes across ARCHITECTURE.md, PRIVACY.md, GETTING_STARTED.md, CONTRIBUTING.md, ROADMAP.md, and SECURITY.md (Swiss German orthography rule). Two of these had survived the v1.0.3 cleanup below (one each in ROADMAP.md and SECURITY.md).

## [1.0.3] - 2026-07-11

### Added

- Documented Dual-Licensing readiness assessment in ROADMAP.md.

### Fixed

- Removed em-dashes from ROADMAP.md and SECURITY.md.

## [1.0.2] - 2026-07-11

### Fixed

- Updated actions/checkout, actions/upload-artifact and softprops/action-gh-release to their latest major versions in the release workflow, since GitHub is deprecating the Node.js 20 runtime and older action versions were being forced onto Node 24 and crashing during post-run cleanup.

## [1.0.1] - 2026-07-10

### Fixed

- Removed em-dashes and en-dashes from README.md/README.de.md, replaced with colons, commas or plain hyphens

## [1.0.0] - 2026-07-10

### Added

- Initial public release of the assessment engine (previously an internal iteration informally called "V14")
- Ten checks across four categories (security, health, storage, management): reboot-pending, uptime, battery health, system-drive free space, local administrators, remote-access tools, Windows edition & license activation, autostart entries, Secure Boot, TPM 2.0
- Self-contained HTML report with embedded JSON, filterable/searchable findings table, and per-category score breakdown
- `Start-Assessment.cmd` launcher with automatic UAC elevation, so the TPM check produces real data by default
- Windows installer (`installer/WorkplaceAssessment.iss`, Inno Setup) as an alternative to the portable script, built and published to GitHub Releases by `.github/workflows/release.yml` on every version tag

### Fixed

- The internal `Finding` helper used a parameter literally named `$args`, which collided with PowerShell's automatic `$args` variable. As a result, every evidence-text placeholder (e.g. `{freeGb}`, `{count}`, `{days}`) across *all* checks was silently never substituted. Renamed the parameter to `$eArgs`; all evidence text now renders with real values.

[1.0.0]: https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases/tag/v1.0.0
