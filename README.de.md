<div align="center">
  <img src="RayStudio.png" alt="RayStudio Logo" width="120"/>

  <h1>WorkplaceAssessment</h1>
</div>

[🇬🇧 English Version](README.md)

**Offline Windows-Gerätezustands- und Windows-11-Fähigkeits-Scanner. Ein PowerShell-Skript, keine Abhängigkeiten, keine Netzwerkzugriffe.**

WorkplaceAssessment prüft Neustartstatus, Laufzeit, Speicherplatz, Akkuzustand, lokale Administratorkonten, Fernwartungstools, Autostart-Einträge, Windows-11-Bereitschaft (Secure Boot, TPM 2.0, CPU, RAM/Speicher, Aktualität des Feature-Updates) sowie eine Sicherheits-Baseline (BitLocker, Defender-Status und -Ausschlüsse, Firewall, Windows-Update-Compliance, RDP-Exposition, Credential Guard/VBS, LAPS) eines Windows-Geräts und erzeugt daraus einen bewerteten, farbcodierten HTML-Report sowie einen maschinenlesbaren JSON-Export. Alles läuft lokal, es wird nie etwas übertragen.

[![CI](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/ci.yml/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions) [![CodeQL](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/security/code-scanning) [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/9t29zhmwdh-coder/WorkplaceAssessment/badge)](https://securityscorecards.dev/viewer/?uri=github.com/9t29zhmwdh-coder/WorkplaceAssessment) [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13682/badge)](https://www.bestpractices.dev/projects/13682)

![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-lightgrey) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Dependencies](https://img.shields.io/badge/Dependencies-none-brightgreen)

> **So läuft es:** WorkplaceAssessment ist ein einzelnes PowerShell-Skript, keine installierte App und kein Hintergrunddienst. Doppelklick auf `Start-Assessment.cmd` genügt: einmal scannen, Report schreiben, fertig, nichts bleibt resident.

**In der Praxis:** Du startest den Launcher, bestätigst optional einen UAC-Prompt (nötig, damit TPM-, BitLocker-, Secure-Boot- und Defender-Ausschlüsse-Check ein echtes Ergebnis liefern), und erhältst einen Report mit Gesamtscore (0-100) und Aufschlüsselung nach fünf gewerteten Kategorien (plus einem rein informativen Microsoft-365-/Entra-Abschnitt, der nicht in den Score einfliesst). Jeder Befund zeigt Evidenz, Risiko und eine konkrete Empfehlung; ein Klick auf eine Zeile öffnet die technischen Rohdaten dahinter. Befunde aus einer Liste (gefundene Fernwartungstools, auffällige Autostart-Einträge, Defender-Ausschlüsse) werden einzeln pro Fund gemeldet statt gebündelt, sodass jeder einzeln geprüft und, falls es sich um eine bekannte/akzeptierte Ausnahme handelt, direkt im Report mit dokumentierter Begründung abgehakt werden kann. Ein Umschalter "Privates Gerät / Firmengerät" oben im Report bestimmt, welche Checks (LAPS, Credential Guard) in die Bewertung einfliessen, da diese nur auf zentral verwalteten Geräten sinnvoll sind.

---

> 🌱 Neu hier? → [Schritt-für-Schritt-Anleitung für Einsteiger](GETTING_STARTED.md)

---

## Prüfungen

| Prüfung | Kategorie | Hinweis |
|---|---|---|
| Neustartstatus | Gerätezustand | Klassifiziert nach Ursache: Windows Update, Treiber, Anwendung oder reine Temp-Bereinigung |
| Laufzeit | Gerätezustand | Markiert lange Laufzeiten (>30 Tage) |
| Akkuzustand | Gerätezustand | Verschleiss-% aus Design- vs. Ist-Kapazität; Desktops ohne Akku werden als nicht anwendbar markiert |
| Freier Speicherplatz | Speicher | Prozentbasierte Schwellenwerte |
| Lokale Administratoren | Verwaltung | Markiert eine ungewöhnlich hohe Admin-Anzahl |
| Fernwartungstools | Verwaltung | Ein Befund pro gefundenem Tool (TeamViewer, AnyDesk, RealVNC, RustDesk u. ä.), einzeln akzeptierbar |
| Windows-Edition & Lizenz | Verwaltung | Markiert Nicht-Business-Editionen (kein BitLocker/GPO/RDP-Host/Domain-Join) und nicht aktivierte Lizenzen |
| LAPS (lokales Admin-Passwort) | Verwaltung | Erkennt Windows LAPS oder Legacy-LAPS; bei als "Privat" markierten Geräten von der Bewertung ausgeschlossen |
| Autostart-Einträge | Sicherheit | Ein Befund pro auffälligem Eintrag; bekannte Muster (z. B. Bing Wallpaper) werden vorab herausgefiltert, um Fehlalarme zu vermeiden |
| BitLocker | Sicherheit | Fällt auf `manage-bde -status` zurück, falls das `Get-BitLockerVolume`-Cmdlet nicht verfügbar ist; validiert die tatsächliche Statuszeile, bevor sie als Ergebnis übernommen wird |
| Windows Defender Status | Sicherheit | Echtzeitschutz, Signaturalter |
| Defender-Ausschlüsse | Sicherheit | Ein Befund pro konfiguriertem Ausschluss (Pfad/Endung/Prozess/IP); Malware trägt sich häufig selbst als Ausschluss ein, um Scans zu umgehen, daher ergibt eine leere Liste 100% |
| Windows-Firewall | Sicherheit | Alle drei Profile |
| Windows-Update-Compliance | Sicherheit | Fällt auf `Get-HotFix` und `Get-Service wuauserv` zurück, falls der Registry-Zeitstempel leer ist |
| RDP-Exposition | Sicherheit | Markiert RDP ohne Network Level Authentication |
| Credential Guard / VBS | Sicherheit | Wird bewertet, wenn verfügbar aber inaktiv; zählt nur bei als "Firmengerät" markierten Geräten in die Gesamtwertung |
| Secure Boot | Windows-11-Bereitschaft | Fällt auf einen Registry-Wert zurück, falls `Confirm-SecureBootUEFI` Elevation benötigt |
| TPM 2.0 | Windows-11-Bereitschaft | Windows-11-Hardwarevoraussetzung; benötigt Elevation für ein echtes Ergebnis |
| CPU-Kompatibilität | Windows-11-Bereitschaft | Heuristik anhand des Modellnamens, keine Garantie |
| RAM-/Speicher-Mindestwerte | Windows-11-Bereitschaft | 4 GB RAM / 64 GB Speicher |
| Windows-Versionsaktualität | Windows-11-Bereitschaft | Vergleicht das installierte Feature-Update (z. B. `24H2`) mit der zum Skriptstand bekannten aktuellsten Version |
| Microsoft 365 / Entra Geräteanbindung | Nur informativ | Meldet Entra-/Intune-Einbindung; zählt nicht in die Bewertung |

---

## Voraussetzungen

- Windows 10 oder 11
- PowerShell 5.1+ (vorinstalliert) oder PowerShell 7+
- Keine Module, keine Internetverbindung, keine Adminrechte für den Basis-Scan (siehe [Elevation](#elevation) unten)

---

## Schnellstart

**Option A: Installer** `WorkplaceAssessment-Setup-*.exe` von den [Releases](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases) herunterladen, ausführen, danach über das Startmenü starten. Installiert nach Program Files mit sauberem Uninstaller-Eintrag unter "Apps & Features".

**Option B: Portabel, ohne Installation**

```powershell
git clone https://github.com/9t29zhmwdh-coder/WorkplaceAssessment
cd WorkplaceAssessment
.\Start-Assessment.cmd
```

**Option C: NuGet-Paket** für skriptgesteuertes Deployment/Flotten-Einsatz ohne Repo-Klon, z. B. aus einer Build-Pipeline oder einem gemeinsamen Tools-Verzeichnis:

```powershell
nuget install WorkplaceAssessment -Source "https://nuget.pkg.github.com/9t29zhmwdh-coder/index.json"
```

Benötigt ein [GitHub Personal Access Token](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-nuget-registry#authenticating-to-github-packages) mit `read:packages`-Scope, hinterlegt als NuGet-Source-Credential; siehe [nuget-publish.yml](.github/workflows/nuget-publish.yml) für den Build-Prozess. Entpackt nach `content/scripts/Invoke-WorkplaceAssessment.ps1` und `content/Start-Assessment.cmd` im Paketordner.

Oder direkt ohne Launcher:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessment.ps1
```

Beide Optionen führen exakt dasselbe Skript aus; der Installer ergänzt lediglich eine Startmenü-/Desktop-Verknüpfung und einen regulären Deinstallations-Eintrag: wähle, was zu deiner Verteilung passt (Installer für eine verwaltete Flotte, portabel für ein USB-Stick-Toolkit).

---

## Zeitlicher Verlaufsvergleich

Führe das Assessment desselben Geräts periodisch aus und vergleiche zwei JSON-Reports, um zu sehen, was sich geändert hat, nicht nur die zwei unabhängigen Momentaufnahmen:

```powershell
.\scripts\Compare-WorkplaceAssessment.ps1 -BaselinePath .\output\Assessment_PC01_2026-06-01.json -CurrentPath .\output\Assessment_PC01_2026-07-01.json
```

Zeigt die Gesamtbewertungsveränderung und eine Tabelle jeder geänderten Prüfung, markiert als `improved`, `regressed`, `new` (existierte im Baseline-Report nicht, z. B. kein Akku erkannt zuvor) oder `removed`. Eine unveränderte Prüfung wird in der Tabelle weggelassen, damit echte Änderungen nicht untergehen. Mit `-OutJson trend.json` wird der Vergleich zusätzlich als JSON gespeichert, z. B. für ein Ticketing-System oder ein Skript, das nur bei `regressed`/`removed` alarmieren soll.

---

## Elevation

`Start-Assessment.cmd` prüft, ob es bereits erhöht läuft, und fordert andernfalls automatisch UAC-Elevation an, bevor der Scan startet. Elevation wird für ein echtes Ergebnis bei folgenden Checks benötigt: TPM 2.0, BitLocker und Defender-Ausschlüsse (`Win32_Tpm`, `Get-BitLockerVolume`/`manage-bde` sowie die Ausschluss-Listen von `Get-MpPreference` verweigern nicht-elevierten Clients unter Windows 11 in der Praxis den Zugriff). Secure Boot funktioniert dank Registry-Fallback auch ohne Elevation, obwohl `Confirm-SecureBootUEFI` selbst Elevation benötigt. Alle anderen Checks funktionieren vollständig ohne Adminrechte; ohne Elevation (z. B. bei direktem Aufruf der `.ps1`) melden die betroffenen Checks „Administratorrechte erforderlich" statt eines falschen Ergebnisses.

---

## Deinstallation / Aufräumen

- **Portable Nutzung (Option B):** Es gibt nichts zu deinstallieren. Ordner löschen genügt. Es werden keine Registry-Einträge, geplanten Aufgaben oder Hintergrunddienste angelegt.
- **Installer-Nutzung (Option A):** Deinstallation über Windows-Einstellungen → Apps oder die Startmenü-Verknüpfung. Entfernt die installierten Dateien sowie den `output/`-Ordner im Installationsverzeichnis.

Keine der beiden Varianten legt geplante Aufgaben oder Hintergrunddienste an: das Tool läuft nur, wenn du aktiv einen Scan auslöst.

---

## Datenschutz

WorkplaceAssessment verarbeitet alles **lokal auf dem gescannten Gerät**. Es werden nie Daten an einen Server gesendet, nicht einmal an `localhost`. Siehe [PRIVACY.md](PRIVACY.md) für die genauen Daten, die in einem Report landen, und warum `output/` in `.gitignore` ausgeschlossen ist.

---

## Architektur

```
WorkplaceAssessment/
├── scripts/Invoke-WorkplaceAssessment.ps1   # gesamte Anwendung, eine Datei
├── Start-Assessment.cmd                     # UAC-elevierender Launcher
└── output/                                  # generierte JSON-/HTML-Reports (nur lokal)
```

Siehe [ARCHITECTURE.md](ARCHITECTURE.md) für das `Finding`-Pattern, das jeder Check nutzt, sowie die Report-Erzeugungs-Pipeline.

---

**Autor:** [Rafael Yilmaz](https://github.com/9t29zhmwdh-coder) · **Status:** Active · ![version](https://img.shields.io/github/v/release/9t29zhmwdh-coder/WorkplaceAssessment?color=6b7280&style=flat-square) · **Lizenz:** MIT
