<div align="center">
  <img src="RayStudio.png" alt="RayStudio Logo" width="120"/>

  <h1>WorkplaceAssessment</h1>
</div>

[🇩🇪 Deutsche Version](README.de.md)

**Offline Windows device health and Windows-11-readiness scanner. One PowerShell script, zero dependencies, zero network calls.**

WorkplaceAssessment checks a Windows machine's reboot state, uptime, storage, battery health, local admin accounts, remote-access tools, autostart entries, Windows 11 readiness (Secure Boot, TPM 2.0, CPU, RAM/storage, feature-update currency), and a security baseline (BitLocker, Defender status and exclusions, Firewall, Windows Update compliance, RDP exposure, Credential Guard/VBS, LAPS), then produces a scored, color-coded HTML report plus a machine-readable JSON export. Everything runs locally; nothing is ever transmitted anywhere.

[![CI](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/ci.yml/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions) [![CodeQL](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/security/code-scanning) [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/9t29zhmwdh-coder/WorkplaceAssessment/badge)](https://securityscorecards.dev/viewer/?uri=github.com/9t29zhmwdh-coder/WorkplaceAssessment) [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13682/badge)](https://www.bestpractices.dev/projects/13682)

![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-lightgrey) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Dependencies](https://img.shields.io/badge/Dependencies-none-brightgreen)

> **How it runs:** WorkplaceAssessment is a single PowerShell script, not an installed app or background service. Double-click `Start-Assessment.cmd`, it scans once, writes a report, and exits, nothing stays resident.

**In practice:** you run the launcher, optionally confirm a UAC prompt (needed for the TPM, BitLocker, Secure Boot and Defender-exclusions checks to return real data), and get a report showing an overall score out of 100 with a breakdown across five scored categories (plus an informational Microsoft 365/Entra section that doesn't count toward the score). Every finding lists its evidence, the risk it represents, and a concrete recommendation; click a row to see the raw technical details behind it. Findings that come from a list (remote-access tools found, suspicious autostart entries, Defender exclusions) are reported one row per item, not bundled, so each one can be reviewed and, if it's a known/accepted exception, checked off individually with a documented reason directly in the report. A "Private device / Company device" toggle at the top of the report adjusts which checks (LAPS, Credential Guard) count toward the score, since those only make sense on a centrally managed device.

---

> 🌱 New here? → [Step-by-step guide for beginners](GETTING_STARTED.md)

---

## Checks

| Check | Category | Notes |
|---|---|---|
| Reboot pending | Health | Classifies by cause: Windows Update, driver, application, or temp-only cleanup |
| Uptime | Health | Flags long uptimes (>30 days) |
| Battery health | Health | Wear % from design vs. full-charge capacity; desktops without a battery are marked not applicable |
| System drive free space | Storage | Percentage-based thresholds |
| Local administrators | Management | Flags an unusually high admin count |
| Remote-access tools | Management | One finding per detected tool (TeamViewer, AnyDesk, RealVNC, RustDesk, and similar), individually acknowledgeable |
| Windows edition & license | Management | Flags non-business editions (no BitLocker/GPO/RDP-host/domain-join) and non-activated licenses |
| LAPS (local admin password) | Management | Detects Windows LAPS or legacy LAPS; excluded from the score on devices marked "Private" |
| Autostart entries | Security | One finding per suspicious entry; known-good patterns (e.g. Bing Wallpaper) are pre-filtered to avoid false positives |
| BitLocker | Security | Falls back to `manage-bde -status` if the `Get-BitLockerVolume` cmdlet is unavailable; validates the actual status line before trusting it |
| Windows Defender status | Security | Real-time protection, signature age |
| Defender exclusions | Security | One finding per configured exclusion (path/extension/process/IP); malware commonly adds itself as an exclusion to evade scanning, so an empty list scores 100% |
| Windows Firewall | Security | All three profiles |
| Windows Update compliance | Security | Falls back to `Get-HotFix` and `Get-Service wuauserv` if the registry timestamp is empty |
| RDP exposure | Security | Flags RDP enabled without Network Level Authentication |
| Credential Guard / VBS | Security | Scored when available-but-inactive; only counts toward the total on devices marked "Company" |
| Secure Boot | Windows 11 Readiness | Falls back to a registry read if `Confirm-SecureBootUEFI` needs elevation |
| TPM 2.0 | Windows 11 Readiness | Windows 11 hardware requirement; needs elevation for a real result |
| CPU compatibility | Windows 11 Readiness | Heuristic based on model name, not a guarantee |
| RAM / storage minimums | Windows 11 Readiness | 4 GB RAM / 64 GB storage |
| Windows version currency | Windows 11 Readiness | Compares the installed feature update (e.g. `24H2`) against the latest known at the time the script was written |
| Microsoft 365 / Entra device join | Informational only | Reports Entra/Intune enrollment; does not count toward the score |

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1+ (built-in) or PowerShell 7+
- No modules, no internet connection, no admin rights for the baseline scan (see [Elevation](#elevation) below)

---

## Quick Start

**Option A: Installer** download `WorkplaceAssessment-Setup-*.exe` from [Releases](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases), run it, and launch from the Start Menu. Installs to Program Files with a proper uninstaller entry in "Apps & Features".

**Option B: Portable, no install**

```powershell
git clone https://github.com/9t29zhmwdh-coder/WorkplaceAssessment
cd WorkplaceAssessment
.\Start-Assessment.cmd
```

Or run the script directly without the launcher:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessment.ps1
```

Both options run the exact same script; the installer just adds a Start Menu/Desktop shortcut and a standard uninstall entry on top of it: pick whichever fits how you distribute the tool (e.g. installer for a managed fleet, portable for a USB-stick toolkit).

---

## Historical Trend Comparison

Run the same device's assessment periodically and compare two JSON reports to see what changed, not just the two independent snapshots:

```powershell
.\scripts\Compare-WorkplaceAssessment.ps1 -BaselinePath .\output\Assessment_PC01_2026-06-01.json -CurrentPath .\output\Assessment_PC01_2026-07-01.json
```

Prints the overall score movement and a table of every check that changed, tagged `improved`, `regressed`, `new` (didn't exist in the baseline, e.g. no battery detected before), or `removed`. A check that stayed the same is omitted from the table so real changes aren't buried. Add `-OutJson trend.json` to also save the comparison as JSON, e.g. for a ticketing system or a script that only wants to alert on `regressed`/`removed`.

---

## Elevation

`Start-Assessment.cmd` checks whether it's already running elevated and, if not, requests UAC elevation automatically before scanning. Elevation is needed for a real result from: TPM 2.0, BitLocker, and Defender exclusions (`Win32_Tpm`, `Get-BitLockerVolume`/`manage-bde`, and `Get-MpPreference`'s exclusion lists all deny non-elevated clients on Windows 11 in practice). Secure Boot works without elevation via a registry fallback even though `Confirm-SecureBootUEFI` itself requires it. Every other check works fully without admin rights; if you skip elevation (e.g. by running the `.ps1` directly), the checks that need it report "administrator rights required" instead of a false result.

---

## Uninstall / Cleanup

- **Portable use (Option B):** there is nothing to uninstall. Delete the folder. No registry entries, no scheduled tasks, no background services are created.
- **Installer use (Option A):** uninstall via Windows Settings → Apps, or the Start Menu shortcut created alongside the app. This removes the installed files and the `output/` folder under the install directory.

Neither install path creates scheduled tasks or background services: the tool only runs while you actively trigger a scan.

---

## Privacy

WorkplaceAssessment processes everything **locally on the scanned device**. No data is ever sent to a remote server, not even to `localhost`. See [PRIVACY.md](PRIVACY.md) for exactly what data ends up in a generated report and why the `output/` folder is gitignored.

---

## Architecture

```
WorkplaceAssessment/
├── scripts/Invoke-WorkplaceAssessment.ps1   # entire application, one file
├── Start-Assessment.cmd                     # UAC-elevating launcher
└── output/                                  # generated JSON + HTML reports (local only)
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the `Finding` pattern used by every check and the report-generation pipeline.

---

**Author:** [Rafael Yilmaz](https://github.com/9t29zhmwdh-coder) · **Status:** Active · ![version](https://img.shields.io/github/v/release/9t29zhmwdh-coder/WorkplaceAssessment?color=6b7280&style=flat-square) · **License:** MIT
