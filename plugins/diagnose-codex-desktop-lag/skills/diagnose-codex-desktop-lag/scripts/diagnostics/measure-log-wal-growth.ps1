[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(5, 120)][int]$SampleSeconds = 30,
    [ValidateRange(2, 30)][int]$IntervalSeconds = 5
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'logs_2.sqlite'
$wal = "$db-wal"
$samples = [System.Collections.Generic.List[object]]::new()
$started = Get-Date
do {
    $file = Get-Item -LiteralPath $wal -ErrorAction SilentlyContinue
    $samples.Add([pscustomobject]@{
        at = (Get-Date).ToString('o')
        bytes = if ($file) { $file.Length } else { 0 }
    })
    if (((Get-Date) - $started).TotalSeconds -lt $SampleSeconds) { Start-Sleep -Seconds $IntervalSeconds }
} while (((Get-Date) - $started).TotalSeconds -lt $SampleSeconds)

$growth = $samples[-1].bytes - $samples[0].bytes
$rate = $growth / [math]::Max(1, ((Get-Date) - $started).TotalSeconds)
New-DiagnosticResult -Check 'log-wal-growth' -Status $(if ($rate -gt 1MB) { 'warning' } else { 'ok' }) -Data @{
    db_path = $db
    sample_seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    growth_bytes = $growth
    growth_bytes_per_second = [math]::Round($rate, 1)
    samples = @($samples)
} | Write-DiagnosticJson
