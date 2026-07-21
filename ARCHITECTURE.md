# Architecture: WorkplaceAssessment

## Overview

WorkplaceAssessment is a pair of self-contained PowerShell scripts. There is no build step, no external module dependency, and no installer requirement: `scripts/Invoke-WorkplaceAssessment.ps1` is the entire scanning application, collecting device signals via built-in Windows cmdlets and WMI/CIM classes, scoring them, and writing a JSON report plus a self-rendering HTML report with an embedded JavaScript viewer. `scripts/Compare-WorkplaceAssessment.ps1` reads two of those JSON reports and diffs them; it touches no CIM/WMI classes and has no Windows-specific dependency of its own. Nothing leaves the machine.

```
WorkplaceAssessment/
├── scripts/
│   ├── Invoke-WorkplaceAssessment.ps1   # scanning application
│   └── Compare-WorkplaceAssessment.ps1  # historical trend comparison between two JSON reports
├── Start-Assessment.cmd                 # UAC-elevating launcher
├── installer/
│   └── WorkplaceAssessment.iss          # Inno Setup script, packages the scripts above
├── nuget/
│   └── WorkplaceAssessment.nuspec       # NuGet package manifest, packages the scripts above
└── output/                              # generated reports (gitignored, local only)
```

## Core Pattern: `Finding`

Every check is a function that returns one or more `Finding` objects:

```powershell
function Finding($cat,$check,$status,$score,$max,$eKey,$eArgs,$risk,$rec,$details=@(),$item=$null){
  [pscustomobject]@{
    categoryKey=$cat; checkKey=$check; statusKey=$status
    score=$score; maxScore=$max; scored=($max -gt 0)
    evidenceKey=$eKey; evidenceArgs=$eArgs
    riskKey=$risk; recommendationKey=$rec; details=$details; itemKey=$item
  }
}
```

- `categoryKey`: one of `security`, `windows11`, `health`, `storage`, `management` (scored) or `m365` (informational only, `maxScore` always `0`)
- `statusKey`: `ok` / `warning` / `critical` / `info`
- `score`/`maxScore`: points earned vs. points possible; `maxScore=0` marks a check as informational only (excluded from scoring, used when a query fails or a check does not apply to the device, e.g. no battery on a desktop)
- `evidenceKey`/`riskKey`/`recommendationKey`: lookup keys into the report's localization dictionary, not raw text
- `evidenceArgs`: a hashtable of values (e.g. `@{freeGb=137.4}`) substituted into the evidence text as `{freeGb}` placeholders at render time
- `details`: optional array of raw technical strings shown when a report row is expanded, for manual follow-up
- `itemKey`: optional identifier that disambiguates multiple `Finding`s sharing the same `categoryKey`/`checkKey` (see "Per-item findings" below); `$null` for checks that only ever produce a single row

Each check function queries one data source defensively (`try`/`catch`), classifies the result into a status/score, and returns a `Finding`. A query failure never throws; it degrades to `info`/`0`/`0` with a "check manually" recommendation, so one unavailable data source (blocked WMI namespace, missing hardware, no elevation) never crashes the whole run or produces a false result for other checks. Where an error message can be told apart from a hard elevation requirement (BitLocker, Defender exclusions, Secure Boot, TPM), the function calls the local `IsAdmin` helper to return a specific "administrator rights required" finding instead of a generic "check manually" one.

### Per-item findings

Checks whose evidence is naturally a *list* (remote-access tools found, suspicious autostart entries, Defender exclusions) do not return one `Finding` that bundles every hit into a single evidence string. Instead they `foreach` over the hits and emit one `Finding` per item, each carrying a distinct `itemKey` (e.g. the tool's display name, the autostart entry name, or `"<type>|<value>"` for an exclusion). PowerShell's pipeline naturally flattens this: a function with a bare `Finding ...` call inside a `foreach` loop streams each call's output as a separate object, so `$findings += RemoteFinding` ends up with N flat, independent `Finding`s rather than one finding containing N nested items. This lets each individual hit be reviewed, filtered, and (in the report UI) acknowledged as an accepted exception on its own, instead of an all-or-nothing bucket. Checks that never produce more than one row (uptime, BitLocker, Secure Boot, etc.) leave `itemKey` as `$null`.

## Current Checks

| Check | Category | Data Source | Notes |
|---|---|---|---|
| Reboot pending | health | Registry (WU/CBS/PendingFileRename) | Classifies pending reboots by cause (Windows Update, driver, application, temp-only) |
| Uptime | health | `Win32_OperatingSystem` | Flags long uptimes (>30 days) |
| Battery health | health | `Win32_Battery`, `root\wmi` `BatteryStaticData`/`BatteryFullChargedCapacity` | Wear % from design vs. full-charge capacity; desktops without a battery are marked not applicable, not failing |
| System drive free space | storage | `Win32_LogicalDisk` | Percentage-based thresholds |
| Local administrators | management | `Get-LocalGroupMember` | Flags an unusually high admin count |
| Remote-access tools | management | Uninstall registry keys | Per-item finding, one per detected tool |
| Windows edition & license | management | `Win32_OperatingSystem`, `SoftwareLicensingProduct` | Flags non-business editions (no BitLocker/GPO/RDP-host/domain-join) and non-activated licenses |
| LAPS | management | Uninstall registry keys, `HKLM:\SOFTWARE\Microsoft\Policies\LAPS` | Company-only check (see "Device mode" below) |
| Autostart entries | security | Run registry keys | Per-item finding, one per suspicious entry; known-good patterns (Bing Wallpaper, Edge Update, OneDriveSetup) are filtered out before matching |
| BitLocker | security | `Get-BitLockerVolume`, falls back to parsing `manage-bde -status` output | The `manage-bde` fallback validates that an actual "Protection Status" line is present before trusting the result, because an access-denied error is also printed to stdout and would otherwise be misread as "BitLocker off" |
| Windows Defender status | security | `Get-MpComputerStatus` | Real-time protection, signature age |
| Defender exclusions | security | `Get-MpPreference` (`ExclusionPath`/`ExclusionExtension`/`ExclusionProcess`/`ExclusionIpAddress`) | Per-item finding, one per configured exclusion; an empty list scores full marks, since malware commonly adds itself as an exclusion to evade scanning |
| Windows Firewall | security | `Get-NetFirewallProfile` | All three profiles |
| Windows Update compliance | security | Registry `LastSuccessTime`, falls back to `Get-HotFix` / `Get-Service wuauserv` | A disabled `wuauserv` service is reported as critical regardless of the last-update date |
| RDP exposure | security | Registry (`fDenyTSConnections`, RDP-Tcp `UserAuthentication`) | Flags RDP enabled without NLA |
| Credential Guard / VBS | security | `Win32_DeviceGuard` | Company-only check (see "Device mode" below) |
| Secure Boot | windows11 | `Confirm-SecureBootUEFI`, falls back to registry `UEFISecureBootEnabled` | The registry fallback works without elevation even though the cmdlet itself requires it |
| TPM 2.0 | windows11 | `Win32_Tpm` (`root\cimv2\Security\MicrosoftTpm`) | Requires an elevated session; degrades to "administrator rights required" when not elevated |
| CPU compatibility | windows11 | `Win32_Processor` | Heuristic name-pattern match (Intel generation, Ryzen series), not authoritative |
| RAM / storage minimums | windows11 | `Win32_ComputerSystem`, `Win32_LogicalDisk` | 4 GB RAM / 64 GB storage, per Microsoft's stated minimums |
| Windows version currency | windows11 | Registry `DisplayVersion`/`CurrentBuild`/`UBR` | Converts `YYHn` version strings to a sequential half-year number so future versions (e.g. `26H1`) compare correctly against the "latest known" constant without needing a lookup table update |
| Microsoft 365 / Entra device join | m365 (informational, `maxScore=0`) | `dsregcmd /status`, `HKLM:\SOFTWARE\Microsoft\Enrollments` | Also feeds `suggestedDeviceMode` in the JSON payload (see below) |

Total: up to 100 points per category across 5 weighted categories (`security`, `windows11`, `health`, `storage`, `management`); `m365` is always informational and never counted.

## Device Mode (Private / Company)

Two checks only make sense on a centrally managed device: **LAPS** (rotated local admin passwords are a fleet-management concept) and **Credential Guard** (expected to be policy-enforced on an Intune-managed device, not meaningful to require on an unmanaged personal machine). Rather than have the PowerShell side guess this from `dsregcmd`/MDM detection alone, the HTML report exposes a "Private device / Company device" toggle at the top of the page (client-side, in the embedded JavaScript). Selecting "Private" excludes those two checks' `maxScore` from the category and overall totals for the current viewing session; selecting "Company" scores them normally. The JSON payload's `suggestedDeviceMode` field (derived server-side from Entra-join + MDM-enrollment state) pre-selects a default, and the user's explicit choice is persisted in `localStorage` per computer name so re-opening the same report keeps the selection.

## Accepted Exceptions (Acknowledge feature)

Any scored finding can be marked as a documented, accepted exception directly in the report: expanding a row's technical details reveals a checkbox and a mandatory free-text reason field. Checking it recomputes that finding's effective score as full marks for the category/overall totals shown in the report (the original score/status is still shown, struck through, for auditability), and the acknowledgement (with reason and timestamp) is persisted in `localStorage` keyed by computer name and included in the "Export JSON" download for an audit trail. This is what lets a per-item finding (e.g. one specific remote-access tool) be signed off individually without needing to remove the tool or wait for the next assessment.

## Report Generation

1. All `Finding` objects are collected into `$findings` and aggregated into per-category and overall scores.
2. The full result is serialized to `output/Assessment_<computer>_<timestamp>.json`.
3. The same JSON is base64-embedded into a self-contained HTML file (`output/Assessment_<computer>_<timestamp>.html`) via a `__DATA_B64__` placeholder substitution.
4. The HTML file requires no server and no network access; it decodes the embedded JSON with vanilla JavaScript and renders it entirely client-side (donut charts, filterable/searchable table, expandable technical details).
5. All display text is looked up from a `const T = {...}` dictionary embedded in the HTML by key (`evidenceKey`, `riskKey`, `recommendationKey`, `categoryKey`, `checkKey`, `statusKey`), currently DE-CH only (see [ROADMAP.md](ROADMAP.md)).
6. The category cards and overall score shown are not simply the PowerShell-computed `scoring` object read verbatim: a client-side `computeScoring()` recalculates them from `data.findings` on every render, applying the accepted-exceptions and device-mode overrides described above. The JSON on disk always reflects the raw, unmodified scan; the interactive adjustments only ever live in the browser (`localStorage`) and in the report the technician is currently looking at.

## Elevation Model

The script does not require administrator rights to run. Most checks work fine unelevated. A handful degrade gracefully instead of failing outright when unelevated:

- **TPM 2.0**: `Win32_Tpm` denies access to a non-elevated CIM client on Windows 11 in practice (confirmed directly, not just per documentation); falls back to `info`/not scored, with a specific "administrator rights required" message (via `IsAdmin`) rather than a generic one.
- **BitLocker**: both `Get-BitLockerVolume` and `manage-bde -status` deny non-elevated access; same "administrator rights required" fallback. Confirmed directly: `manage-bde` still exits with an access-denied message printed to stdout (not just stderr), which is why the fallback parser insists on actually finding a "Protection Status" line before trusting the output, instead of trusting any non-empty output.
- **Defender exclusions**: `Get-MpPreference`'s exclusion properties return the literal string `"N/A: Must be an administrator..."` per entry instead of throwing, when unelevated. The check treats an all-placeholder result as "needs admin" rather than counting the placeholder strings as real exclusions.
- **Secure Boot**: `Confirm-SecureBootUEFI` itself requires elevation, but the check falls back to reading `HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State\UEFISecureBootEnabled`, which is readable without elevation, so Secure Boot resolves to a real result either way.
- **Battery wear**: depends on `root\wmi` `BatteryStaticData`, which some device drivers (observed on a Surface device) don't populate at all, independent of elevation; falls back to `info`/not scored, current charge is still shown.

`Start-Assessment.cmd` requests UAC elevation automatically (`net session` check + self-relaunch via `Start-Process -Verb RunAs`) so TPM, BitLocker, and Defender-exclusions checks produce a real result in the common case. Running the `.ps1` directly, without the `.cmd` wrapper, skips elevation and those checks will report "administrator rights required" (Secure Boot still resolves via its registry fallback regardless).

## External Dependencies

None at runtime. Only built-in Windows PowerShell cmdlets and CIM/WMI classes. No modules to install, no network calls, no telemetry.

## Installer Build

`installer/WorkplaceAssessment.iss` is an [Inno Setup](https://jrsoftware.org/isinfo.php) script that packages `scripts/Invoke-WorkplaceAssessment.ps1`, `Start-Assessment.cmd`, and the docs into a Program Files install with a Start Menu shortcut and a standard uninstaller entry. It changes nothing about how the application itself runs; it's purely a distribution wrapper around the same two files used in the portable case.

`.github/workflows/release.yml` compiles this script on `windows-latest` (via Chocolatey's `innosetup` package) whenever a `v*.*.*` tag is pushed, and attaches the resulting `WorkplaceAssessment-Setup-<version>.exe` to a GitHub Release. It can also be triggered manually (`workflow_dispatch`) to produce a test build without cutting a release.

## NuGet Package

`nuget/WorkplaceAssessment.nuspec` packages the same two scripts, `Start-Assessment.cmd`, and the docs as a plain content-only NuGet package (no `install.ps1`/tools-folder auto-execution: the package is a way to fetch the files, not to trigger a scan on install). `.github/workflows/nuget-publish.yml` packs it with `nuget.exe` (via Chocolatey) and pushes it to this repository's GitHub Packages NuGet feed whenever a `v*.*.*` tag is pushed, or on demand via `workflow_dispatch` with an explicit version (used to backfill a package for a version whose tag was already pushed before this workflow existed). Consumers need a GitHub personal access token with `read:packages` scope to `nuget install` from a private feed; see the README's "Option C" for the exact command.
