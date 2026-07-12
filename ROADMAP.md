# Roadmap: WorkplaceAssessment

## v1.0.0: Initial Public Release ✅

- Reboot-pending, uptime, storage, local-admin, remote-access-tool, and autostart checks
- Secure Boot check
- TPM 2.0 presence/activation check (Windows 11 hardware requirement)
- Windows edition & license-activation check (Pro/Enterprise/Education + activation status)
- Battery health check (design vs. full-charge capacity wear)
- Self-contained HTML report (embedded JSON, filterable/searchable table, donut charts) plus raw JSON export
- Zero external dependencies, zero network calls, zero telemetry
- UAC-elevating launcher (`Start-Assessment.cmd`) so the TPM check gets real data by default
- Windows installer (`installer/WorkplaceAssessment.iss`, built via `.github/workflows/release.yml`) alongside the portable script, for managed-fleet distribution with a proper Start Menu entry and uninstaller

## Known Limitations

- **Report UI is DE-CH only.** The script accepts a `-Lang` parameter with `EN` as a valid value, but the embedded localization dictionary only has German text; passing `-Lang EN` currently has no effect on the rendered report. Tracked for v1.1.0.
- **TPM and battery-wear checks need elevation or capable drivers.** These degrade to "not scored" rather than a false result when the underlying WMI query is denied or unsupported by the device driver; see [ARCHITECTURE.md](ARCHITECTURE.md#elevation-model).

## v1.1.0: Localization & CPU Compatibility

- Real English translations in the report's `T` dictionary, `-Lang EN` actually switches the rendered text
- Windows 11 CPU-generation compatibility check (Intel 8th gen+ / AMD Ryzen 2000+ allow-list, matching Microsoft's published minimum requirements)
- Explicit RAM check (Windows 11 minimum: 4 GB, recommended 8 GB+)

## v1.2.0: Fleet Reporting

- CSV export alongside JSON/HTML for spreadsheet-based fleet tracking
- Optional batch mode: run against a list of remote computers via PowerShell remoting, aggregate results into one fleet-level summary
- Historical trend comparison between two JSON reports for the same device

## Out of Scope

- Any telemetry, analytics, or upload of scan results to a remote service: this tool stays local-only by design
- Automatic remediation without explicit user confirmation (e.g. auto-enabling TPM, auto-restarting the device)
- Non-Windows platforms: the tool is built entirely on Windows-specific CIM classes and cmdlets (`Confirm-SecureBootUEFI`, `Win32_Tpm`, `SoftwareLicensingProduct`) and has no cross-platform path
