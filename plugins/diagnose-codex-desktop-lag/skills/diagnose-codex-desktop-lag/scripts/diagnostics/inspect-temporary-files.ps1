[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(1, 3650)][int]$StaleDays = 7,
    [ValidateRange(1, 100)][int]$Top = 20
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$cutoff = (Get-Date).AddDays(-$StaleDays)
$roots = @('.tmp', 'tmp') | ForEach-Object { Join-Path $CodexHome $_ } | Where-Object { Test-Path -LiteralPath $_ }
$files = foreach ($root in $roots) {
    Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue
}
$stale = @($files | Where-Object { $_.LastWriteTime -lt $cutoff })
$largest = @($files | Sort-Object Length -Descending | Select-Object -First $Top | ForEach-Object {
    [pscustomobject]@{ path = $_.FullName; bytes = $_.Length; last_write = $_.LastWriteTime.ToString('o') }
})
New-DiagnosticResult -Check 'temporary-files' -Status $(if ($stale.Count -gt 1000 -or ($stale | Measure-Object Length -Sum).Sum -gt 500MB) { 'warning' } else { 'ok' }) -Data @{
    roots = @($roots)
    file_count = @($files).Count
    total_bytes = ($files | Measure-Object Length -Sum).Sum
    stale_days = $StaleDays
    stale_file_count = $stale.Count
    stale_bytes = ($stale | Measure-Object Length -Sum).Sum
    largest = $largest
} | Write-DiagnosticJson
