[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$BackupDirectory,
    [string]$CodexHome = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$backup = Assert-PathUnderRoot -Path $BackupDirectory -Root (Join-Path $CodexHome 'performance-backups')
if (-not (Test-Path -LiteralPath $backup -PathType Container)) { throw "Backup directory not found: $backup" }
$knownNames = @('state_5.sqlite', 'logs_2.sqlite', 'config.toml', '.codex-global-state.json', 'session_index.jsonl')
$files = @($knownNames | ForEach-Object {
    $candidate = Join-Path $backup $_
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
})
$manifestPath = Join-Path $backup 'archive-manifest.json'
$manifest = if (Test-Path -LiteralPath $manifestPath) { Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json } else { $null }
$preRestore = Join-Path $CodexHome ('performance-backups/pre-restore-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

if ($PSCmdlet.ShouldProcess($CodexHome, "Restore $($files.Count) known Codex state file(s) from $backup")) {
    Assert-CodexStopped
    [IO.Directory]::CreateDirectory($preRestore) | Out-Null
    foreach ($source in $files) {
        $name = [IO.Path]::GetFileName($source)
        $target = Join-Path $CodexHome $name
        if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination $preRestore }
        if ($name -match '\.sqlite$') {
            foreach ($suffix in @('-wal', '-shm')) {
                $sidecar = "$target$suffix"
                if (Test-Path -LiteralPath $sidecar) {
                    Move-Item -LiteralPath $sidecar -Destination $preRestore
                }
            }
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    if ($manifest -and (Test-Path -LiteralPath $manifest.destination) -and -not (Test-Path -LiteralPath $manifest.source)) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($manifest.source)) | Out-Null
        Move-Item -LiteralPath $manifest.destination -Destination $manifest.source
    }
}
[pscustomobject]@{ action = 'restore-codex-backup'; backup = $backup; files = @($files); archive_manifest = [bool]$manifest; pre_restore_backup = $preRestore; applied = -not $WhatIfPreference } | ConvertTo-Json -Depth 5
