<div align="center">
  <img src="RayStudio.png" alt="RayStudio Logo" width="120"/>

  <h1>WorkplaceAssessment</h1>
</div>

[🇩🇪 Deutsche Version](README.de.md)

**Offline Windows device health and Windows-11-readiness scanner. One PowerShell script, zero dependencies, zero network calls.**

WorkplaceAssessment checks a Windows machine's reboot state, uptime, storage, local admin accounts, remote-access tools, autostart entries, Secure Boot, TPM 2.0 readiness, Windows edition/license activation, and battery health, then produces a scored, color-coded HTML report plus a machine-readable JSON export. Everything runs locally; nothing is ever transmitted anywhere.

[![CI](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/ci.yml/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions) [![CodeQL](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/security/code-scanning) [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/9t29zhmwdh-coder/WorkplaceAssessment/badge)](https://securityscorecards.dev/viewer/?uri=github.com/9t29zhmwdh-coder/WorkplaceAssessment)
![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-lightgrey) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Dependencies](https://img.shields.io/badge/Dependencies-none-brightgreen)

> **How it runs:** WorkplaceAssessment is a single PowerShell script, not an installed app or background service. Double-click `Start-Assessment.cmd`, it scans once, writes a report, and exits, nothing stays resident.

**In practice:** you run the launcher, optionally confirm a UAC prompt (needed for the TPM check to return real data), and get a report showing an overall score out of 100 with a breakdown across four categories. Every finding lists its evidence, the risk it represents, and a concrete recommendation; click a row to see the raw technical details behind it.

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
| Remote-access tools | Management | Detects TeamViewer, AnyDesk, RealVNC, RustDesk, and similar |
| Windows edition & license | Management | Flags non-business editions (no BitLocker/GPO/RDP-host/domain-join) and non-activated licenses |
| Autostart entries | Security | Heuristic match for suspicious autostart patterns |
| Secure Boot | Security | |
| TPM 2.0 | Security | Windows 11 hardware requirement; needs elevation for a real result |

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

`Start-Assessment.cmd` checks whether it's already running elevated and, if not, requests UAC elevation automatically before scanning. This is only needed for the TPM 2.0 check: `Win32_Tpm` denies non-elevated CIM clients on Windows 11 in practice. Every other check works fully without admin rights; if you skip elevation (e.g. by running the `.ps1` directly), the TPM check simply reports "not scored" instead of a false result.

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
