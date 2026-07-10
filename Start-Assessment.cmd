@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Admin-Rechte erforderlich fuer den TPM-Check ^(Windows-11-Faehigkeit^). UAC-Bestaetigung wird angefordert...
  powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0scripts\Invoke-WorkplaceAssessment.ps1\" %*' -Verb RunAs -Wait"
  goto :end
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Invoke-WorkplaceAssessment.ps1" %*
if errorlevel 1 (
  echo.
  echo Workplace Assessment failed. Keep this window open and check the output.
  pause >nul
)

:end
endlocal
