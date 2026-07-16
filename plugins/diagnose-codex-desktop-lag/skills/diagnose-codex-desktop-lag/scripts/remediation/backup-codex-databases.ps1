[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$CodexHome = '',
    [string]$BackupRoot = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
if (-not $BackupRoot) { $BackupRoot = Join-Path $CodexHome 'performance-backups' }
$destination = Join-Path $BackupRoot ('databases-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$sources = @('state_5.sqlite', 'logs_2.sqlite') | ForEach-Object { Join-Path $CodexHome $_ } | Where-Object { Test-Path -LiteralPath $_ }

if ($PSCmdlet.ShouldProcess($destination, "Create online SQLite backups for $($sources.Count) database(s)")) {
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    foreach ($source in $sources) {
        Backup-SqliteDatabase -Source $source -Destination (Join-Path $destination ([IO.Path]::GetFileName($source)))
    }
}
[pscustomobject]@{ action = 'backup-codex-databases'; destination = $destination; sources = @($sources); applied = -not $WhatIfPreference } | ConvertTo-Json -Depth 5
