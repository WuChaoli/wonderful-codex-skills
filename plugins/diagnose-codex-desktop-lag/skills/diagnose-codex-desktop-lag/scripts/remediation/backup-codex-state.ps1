[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$CodexHome = '',
    [string]$BackupRoot = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
if (-not $BackupRoot) { $BackupRoot = Join-Path $CodexHome 'performance-backups' }
$destination = Join-Path $BackupRoot ('state-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$names = @('config.toml', '.codex-global-state.json', 'session_index.jsonl')
$sources = $names | ForEach-Object { Join-Path $CodexHome $_ } | Where-Object { Test-Path -LiteralPath $_ }

if ($PSCmdlet.ShouldProcess($destination, "Back up $($sources.Count) Codex state file(s)")) {
    Assert-CodexStopped
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    foreach ($source in $sources) { Copy-Item -LiteralPath $source -Destination $destination }
}
[pscustomobject]@{ action = 'backup-codex-state'; destination = $destination; sources = @($sources); applied = -not $WhatIfPreference } | ConvertTo-Json -Depth 5
