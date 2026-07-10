# Getting Started with WorkplaceAssessment

This guide walks you through running WorkplaceAssessment from scratch, even if you have never used PowerShell or a terminal before. WorkplaceAssessment is a Windows-only script — there is nothing to compile and nothing to install.

---

## 1. Get the code

**Easiest way (no git required):**
1. Go to the [WorkplaceAssessment GitHub page](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment)
2. Click the green **"Code"** button → **"Download ZIP"**
3. Extract the ZIP file somewhere convenient, e.g. `C:\Tools\WorkplaceAssessment`

**Alternative (if you have git):**
```powershell
git clone https://github.com/9t29zhmwdh-coder/WorkplaceAssessment.git
```

## 2. Run it

Open the extracted folder in File Explorer and double-click **`Start-Assessment-v14.cmd`**.

A UAC prompt ("Do you want to allow this app to make changes to your device?") appears — click **Yes**. This is required for the TPM 2.0 check to produce a real result; without it, that one check simply reports "not scored" instead of failing.

## 3. What you should see

A console window flashes briefly while the checks run (a few seconds), then your default browser opens automatically with the report: a color-coded score, a category breakdown, and a searchable table of findings. Click any row to expand its technical details. A machine-readable JSON copy is saved next to the HTML report in the `output/` folder.

## 4. Running without the UAC prompt

If you don't want the elevation prompt (e.g. scripted/unattended use), run the `.ps1` directly instead of the `.cmd`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessmentV14.ps1
```

All checks except TPM (and, on some devices, battery-wear detail) still work fully unelevated — see [ARCHITECTURE.md](ARCHITECTURE.md#elevation-model).

## Command-line Options

| Parameter | Description |
|---|---|
| `-NoOpen` | Generates the report without opening it in the browser afterward |
| `-Lang <DE-CH\|EN>` | Report language — **currently DE-CH only has translated text**, `EN` is accepted but has no visible effect yet (see [ROADMAP.md](ROADMAP.md)) |

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| PowerShell blocks the script with an execution policy error | Windows execution policy defaults to "Restricted" | Both `Start-Assessment-v14.cmd` and the documented direct command already pass `-ExecutionPolicy Bypass`; if you're invoking PowerShell some other way, add that flag yourself |
| UAC prompt doesn't appear / TPM check still says "not scored" | Prompt was dismissed, or you ran the `.ps1` directly instead of the `.cmd` | Re-run `Start-Assessment-v14.cmd` and accept the UAC prompt |
| Report shows "Nicht bewertet" for battery wear | Some device drivers (observed on certain Surface models) don't expose design-capacity data via WMI, independent of admin rights | Current charge is still shown; wear percentage isn't available on that specific device |
| Browser doesn't open automatically | `-NoOpen` was passed, or no default browser is configured | Open the generated `.html` file from `output/` manually |
