[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$RolloutPath,
    [string]$CodexHome = '',
    [string]$QuarantineRoot = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
if (-not $QuarantineRoot) { $QuarantineRoot = Join-Path $CodexHome 'performance-quarantine/rollouts' }
$resolved = [IO.Path]::GetFullPath($RolloutPath)
$allowed = @((Join-Path $CodexHome 'sessions'), (Join-Path $CodexHome 'archived_sessions'))
if (-not ($allowed | Where-Object { $resolved.StartsWith([IO.Path]::GetFullPath($_) + '\', [StringComparison]::OrdinalIgnoreCase) })) {
    throw 'RolloutPath must be under Codex sessions or archived_sessions.'
}
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Rollout file not found: $resolved" }
$destinationDir = Join-Path $QuarantineRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
$destination = Join-Path $destinationDir ([IO.Path]::GetFileName($resolved))
if ($PSCmdlet.ShouldProcess($resolved, "Move rollout to reversible quarantine: $destination")) {
    Assert-CodexStopped
    [IO.Directory]::CreateDirectory($destinationDir) | Out-Null
    Move-Item -LiteralPath $resolved -Destination $destination
}
[pscustomobject]@{ action = 'quarantine-rollout-file'; source = $resolved; destination = $destination; applied = -not $WhatIfPreference } | ConvertTo-Json
