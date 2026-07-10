<div align="center">
  <img src="RayStudio.png" alt="RayStudio Logo" width="120"/>

  <h1>WorkplaceAssessment</h1>
</div>

[🇬🇧 English Version](README.md)

**Offline Windows-Gerätezustands- und Windows-11-Fähigkeits-Scanner. Ein PowerShell-Skript, keine Abhängigkeiten, keine Netzwerkzugriffe.**

WorkplaceAssessment prüft Neustartstatus, Laufzeit, Speicherplatz, lokale Administratorkonten, Fernwartungstools, Autostart-Einträge, Secure Boot, TPM-2.0-Bereitschaft, Windows-Edition/Lizenzaktivierung und Akkuzustand eines Windows-Geräts und erzeugt daraus einen bewerteten, farbcodierten HTML-Report sowie einen maschinenlesbaren JSON-Export. Alles läuft lokal, es wird nie etwas übertragen.

[![CI](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions/workflows/ci.yml/badge.svg)](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/actions) ![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-lightgrey) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Dependencies](https://img.shields.io/badge/Dependencies-none-brightgreen) ![License](https://img.shields.io/badge/License-MIT-blue)

> **So läuft es:** WorkplaceAssessment ist ein einzelnes PowerShell-Skript, keine installierte App und kein Hintergrunddienst. Doppelklick auf `Start-Assessment.cmd` genügt: einmal scannen, Report schreiben, fertig — nichts bleibt resident.

**In der Praxis:** Du startest den Launcher, bestätigst optional einen UAC-Prompt (nötig, damit der TPM-Check ein echtes Ergebnis liefert), und erhältst einen Report mit Gesamtscore (0–100) und Aufschlüsselung nach vier Kategorien. Jeder Befund zeigt Evidenz, Risiko und eine konkrete Empfehlung; ein Klick auf eine Zeile öffnet die technischen Rohdaten dahinter.

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
| Fernwartungstools | Verwaltung | Erkennt TeamViewer, AnyDesk, RealVNC, RustDesk und ähnliche |
| Windows-Edition & Lizenz | Verwaltung | Markiert Nicht-Business-Editionen (kein BitLocker/GPO/RDP-Host/Domain-Join) und nicht aktivierte Lizenzen |
| Autostart-Einträge | Sicherheit | Heuristischer Abgleich auf auffällige Autostart-Muster |
| Secure Boot | Sicherheit | |
| TPM 2.0 | Sicherheit | Windows-11-Hardwarevoraussetzung; benötigt Elevation für ein echtes Ergebnis |

---

## Voraussetzungen

- Windows 10 oder 11
- PowerShell 5.1+ (vorinstalliert) oder PowerShell 7+
- Keine Module, keine Internetverbindung, keine Adminrechte für den Basis-Scan (siehe [Elevation](#elevation) unten)

---

## Schnellstart

**Option A — Installer:** `WorkplaceAssessment-Setup-*.exe` von den [Releases](https://github.com/9t29zhmwdh-coder/WorkplaceAssessment/releases) herunterladen, ausführen, danach über das Startmenü starten. Installiert nach Program Files mit sauberem Uninstaller-Eintrag unter "Apps & Features".

**Option B — Portabel, ohne Installation:**

```powershell
git clone https://github.com/9t29zhmwdh-coder/WorkplaceAssessment
cd WorkplaceAssessment
.\Start-Assessment.cmd
```

Oder direkt ohne Launcher:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WorkplaceAssessment.ps1
```

Beide Optionen führen exakt dasselbe Skript aus; der Installer ergänzt lediglich eine Startmenü-/Desktop-Verknüpfung und einen regulären Deinstallations-Eintrag — wähle, was zu deiner Verteilung passt (Installer für eine verwaltete Flotte, portabel für ein USB-Stick-Toolkit).

---

## Elevation

`Start-Assessment.cmd` prüft, ob es bereits erhöht läuft, und fordert andernfalls automatisch UAC-Elevation an, bevor der Scan startet. Das ist ausschliesslich für den TPM-2.0-Check nötig — `Win32_Tpm` verweigert nicht-elevierten CIM-Clients unter Windows 11 in der Praxis den Zugriff. Alle anderen Checks funktionieren vollständig ohne Adminrechte; ohne Elevation (z. B. bei direktem Aufruf der `.ps1`) meldet der TPM-Check schlicht „Nicht bewertet" statt eines falschen Ergebnisses.

---

## Deinstallation / Aufräumen

- **Portable Nutzung (Option B):** Es gibt nichts zu deinstallieren. Ordner löschen genügt. Es werden keine Registry-Einträge, geplanten Aufgaben oder Hintergrunddienste angelegt.
- **Installer-Nutzung (Option A):** Deinstallation über Windows-Einstellungen → Apps oder die Startmenü-Verknüpfung. Entfernt die installierten Dateien sowie den `output/`-Ordner im Installationsverzeichnis.

Keine der beiden Varianten legt geplante Aufgaben oder Hintergrunddienste an — das Tool läuft nur, wenn du aktiv einen Scan auslöst.

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
