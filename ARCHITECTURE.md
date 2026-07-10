# Architecture — WorkplaceAssessment

## Overview

WorkplaceAssessment is a single, self-contained PowerShell script. There is no build step, no external module dependency, and no installer — `scripts/Invoke-WorkplaceAssessmentV14.ps1` is the entire application. It collects device signals via built-in Windows cmdlets and WMI/CIM classes, scores them, and writes a JSON report plus a self-rendering HTML report with an embedded JavaScript viewer. Nothing leaves the machine.

```
WorkplaceAssessment/
├── scripts/
│   └── Invoke-WorkplaceAssessmentV14.ps1   # entire application
├── Start-Assessment-v14.cmd                # UAC-elevating launcher
└── output/                                 # generated reports (gitignored, local only)
```

## Core Pattern: `Finding`

Every check is a function that returns one or more `Finding` objects:

```powershell
function Finding($cat,$check,$status,$score,$max,$eKey,$eArgs,$risk,$rec,$details=@()){
  [pscustomobject]@{
    categoryKey=$cat; checkKey=$check; statusKey=$status
    score=$score; maxScore=$max; scored=($max -gt 0)
    evidenceKey=$eKey; evidenceArgs=$eArgs
    riskKey=$risk; recommendationKey=$rec; details=$details
  }
}
```

- `categoryKey` — one of `security`, `health`, `storage`, `management`
- `statusKey` — `ok` / `warning` / `critical` / `info`
- `score`/`maxScore` — points earned vs. points possible; `maxScore=0` marks a check as informational only (excluded from scoring, used when a query fails or a check does not apply to the device, e.g. no battery on a desktop)
- `evidenceKey`/`riskKey`/`recommendationKey` — lookup keys into the report's localization dictionary, not raw text
- `evidenceArgs` — a hashtable of values (e.g. `@{freeGb=137.4}`) substituted into the evidence text as `{freeGb}` placeholders at render time
- `details` — optional array of raw technical strings shown when a report row is expanded, for manual follow-up

Each check function queries one data source defensively (`try`/`catch`), classifies the result into a status/score, and returns a `Finding`. A query failure never throws — it degrades to `info`/`0`/`0` with a "check manually" recommendation, so one unavailable data source (blocked WMI namespace, missing hardware, no elevation) never crashes the whole run or produces a false result for other checks.

## Current Checks

| Check | Category | Data Source | Notes |
|---|---|---|---|
| Reboot pending | health | Registry (WU/CBS/PendingFileRename) | Classifies pending reboots by cause (Windows Update, driver, application, temp-only) |
| Uptime | health | `Win32_OperatingSystem` | Flags long uptimes (>30 days) |
| Battery health | health | `Win32_Battery`, `root\wmi` `BatteryStaticData`/`BatteryFullChargedCapacity` | Wear % from design vs. full-charge capacity; desktops without a battery are marked not applicable, not failing |
| System drive free space | storage | `Win32_LogicalDisk` | Percentage-based thresholds |
| Local administrators | management | `Get-LocalGroupMember` | Flags an unusually high admin count |
| Remote-access tools | management | Uninstall registry keys | Pattern match against known remote-support tools |
| Windows edition & license | management | `Win32_OperatingSystem`, `SoftwareLicensingProduct` | Flags non-business editions (no BitLocker/GPO/RDP-host/domain-join) and non-activated licenses |
| Autostart entries | security | Run registry keys | Heuristic match for suspicious autostart patterns |
| Secure Boot | security | `Confirm-SecureBootUEFI` | |
| TPM 2.0 | security | `Win32_Tpm` (`root\cimv2\Security\MicrosoftTpm`) | Requires an elevated session; degrades to informational when not elevated |

Total: 100 points across 4 weighted categories.

## Report Generation

1. All `Finding` objects are collected into `$findings` and aggregated into per-category and overall scores.
2. The full result is serialized to `output/Assessment_<computer>_<timestamp>.json`.
3. The same JSON is base64-embedded into a self-contained HTML file (`output/Assessment_<computer>_<timestamp>.html`) via a `__DATA_B64__` placeholder substitution.
4. The HTML file requires no server and no network access — it decodes the embedded JSON with vanilla JavaScript and renders it entirely client-side (donut charts, filterable/searchable table, expandable technical details).
5. All display text is looked up from a `const T = {...}` dictionary embedded in the HTML by key (`evidenceKey`, `riskKey`, `recommendationKey`, `categoryKey`, `checkKey`, `statusKey`) — currently DE-CH only (see [ROADMAP.md](ROADMAP.md)).

## Elevation Model

The script does not require administrator rights to run. Most checks work fine unelevated. Two exceptions degrade gracefully instead of failing outright when unelevated:

- **TPM 2.0**: `Win32_Tpm` denies access to a non-elevated CIM client on Windows 11 in practice (confirmed directly, not just per documentation) — falls back to `info`/not scored.
- **Battery wear**: depends on `root\wmi` `BatteryStaticData`, which some device drivers (observed on a Surface device) don't populate at all, independent of elevation — falls back to `info`/not scored, current charge is still shown.

`Start-Assessment-v14.cmd` requests UAC elevation automatically (`net session` check + self-relaunch via `Start-Process -Verb RunAs`) so the TPM check produces a real result in the common case. Running the `.ps1` directly, without the `.cmd` wrapper, skips elevation and TPM will report "not scored".

## External Dependencies

None. Only built-in Windows PowerShell cmdlets and CIM/WMI classes. No modules to install, no network calls, no telemetry.
