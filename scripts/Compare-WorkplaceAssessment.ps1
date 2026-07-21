<#
.SYNOPSIS
Compares two WorkplaceAssessment JSON reports for the same device and shows
which checks improved, regressed, or newly appeared/disappeared between runs.

.DESCRIPTION
Historical trend comparison for fleet reporting: point this at an older and a
newer JSON report (both produced by Invoke-WorkplaceAssessment.ps1) to see
score movement per check, not just the two independent snapshots. A check
present in only one report is reported as 'new' or 'removed' rather than
silently ignored, so a driver update that makes a whole check newly scorable
(or unscorable) is visible instead of hidden in the diff.

.EXAMPLE
.\Compare-WorkplaceAssessment.ps1 -BaselinePath .\output\Assessment_PC01_2026-06-01.json -CurrentPath .\output\Assessment_PC01_2026-07-01.json

.EXAMPLE
.\Compare-WorkplaceAssessment.ps1 -BaselinePath old.json -CurrentPath new.json -OutJson trend.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselinePath,
    [Parameter(Mandatory)][string]$CurrentPath,
    [string]$OutJson
)

$ErrorActionPreference = 'Stop'

function Get-AssessmentReport {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Report not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $report = $raw | ConvertFrom-Json
    if (-not $report.findings) {
        throw "$Path does not look like a WorkplaceAssessment report (no 'findings' property)"
    }
    return $report
}

function Get-FindingKey {
    param($Finding)
    # Some checks (remote-access tools, autostart entries, Defender exclusions) emit one Finding
    # per detected item and disambiguate them via itemKey; without it, multiple findings sharing
    # the same categoryKey/checkKey would silently overwrite each other in the lookup below.
    if ($Finding.itemKey) {
        return "$($Finding.categoryKey)/$($Finding.checkKey)/$($Finding.itemKey)"
    }
    return "$($Finding.categoryKey)/$($Finding.checkKey)"
}

function Get-FindingComparison {
    param($Baseline, $Current)

    $baselineByKey = @{}
    foreach ($f in $Baseline.findings) { $baselineByKey[(Get-FindingKey $f)] = $f }
    $currentByKey = @{}
    foreach ($f in $Current.findings) { $currentByKey[(Get-FindingKey $f)] = $f }

    $allKeys = @($baselineByKey.Keys) + @($currentByKey.Keys) | Select-Object -Unique | Sort-Object

    foreach ($key in $allKeys) {
        $old = $baselineByKey[$key]
        $new = $currentByKey[$key]

        $trend =
            if (-not $old) { 'new' }
            elseif (-not $new) { 'removed' }
            elseif ($new.score -gt $old.score) { 'improved' }
            elseif ($new.score -lt $old.score) { 'regressed' }
            else { 'unchanged' }

        [pscustomobject]@{
            check     = $key
            oldStatus = if ($old) { $old.statusKey } else { $null }
            oldScore  = if ($old) { $old.score } else { $null }
            newStatus = if ($new) { $new.statusKey } else { $null }
            newScore  = if ($new) { $new.score } else { $null }
            trend     = $trend
        }
    }
}

$baseline = Get-AssessmentReport -Path $BaselinePath
$current = Get-AssessmentReport -Path $CurrentPath

if ($baseline.computer -and $current.computer -and $baseline.computer -ne $current.computer) {
    Write-Warning "Comparing reports from different computers: '$($baseline.computer)' vs '$($current.computer)'"
}

$changes = @(Get-FindingComparison -Baseline $baseline -Current $current)

$summary = [pscustomobject]@{
    computer        = $current.computer
    baselineDate    = $baseline.completed
    currentDate     = $current.completed
    baselineOverall = $baseline.scoring.percent
    currentOverall  = $current.scoring.percent
    overallDelta    = $current.scoring.percent - $baseline.scoring.percent
    improvedCount   = @($changes | Where-Object { $_.trend -eq 'improved' }).Count
    regressedCount  = @($changes | Where-Object { $_.trend -eq 'regressed' }).Count
    newCount        = @($changes | Where-Object { $_.trend -eq 'new' }).Count
    removedCount    = @($changes | Where-Object { $_.trend -eq 'removed' }).Count
}

$deltaSign = if ($summary.overallDelta -ge 0) { '+' } else { '' }
Write-Host "Trend comparison: $($summary.computer)" -ForegroundColor Cyan
Write-Host "  $($summary.baselineDate) -> $($summary.currentDate)"
Write-Host "  Overall score: $($summary.baselineOverall)% -> $($summary.currentOverall)% ($deltaSign$($summary.overallDelta))"
Write-Host "  Improved: $($summary.improvedCount)  Regressed: $($summary.regressedCount)  New: $($summary.newCount)  Removed: $($summary.removedCount)"

$notable = @($changes | Where-Object { $_.trend -ne 'unchanged' })
if ($notable.Count -gt 0) {
    $notable | Sort-Object trend, check | Format-Table -AutoSize
} else {
    Write-Host "  No changes between the two reports."
}

if ($OutJson) {
    [pscustomobject]@{ summary = $summary; changes = $changes } |
        ConvertTo-Json -Depth 8 |
        Out-File -LiteralPath $OutJson -Encoding utf8
    Write-Host "Comparison written to $OutJson"
}
