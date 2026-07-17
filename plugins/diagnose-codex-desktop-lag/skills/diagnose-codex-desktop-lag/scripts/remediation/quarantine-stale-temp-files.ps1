[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$CodexHome = '',
    [ValidateRange(1, 3650)][int]$OlderThanDays = 7,
    [string]$QuarantineRoot = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
if (-not $QuarantineRoot) { $QuarantineRoot = Join-Path $CodexHome 'performance-quarantine/temp' }
$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$roots = @('.tmp', 'tmp') | ForEach-Object { Join-Path $CodexHome $_ } | Where-Object { Test-Path -LiteralPath $_ }
$candidates = @($roots | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse -Force -ErrorAction SilentlyContinue } | Where-Object { $_.LastWriteTime -lt $cutoff })
$destination = Join-Path $QuarantineRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
if ($PSCmdlet.ShouldProcess("$($candidates.Count) stale temporary file(s)", "Move to $destination")) {
    Assert-CodexStopped
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    foreach ($file in $candidates) {
        $relative = [IO.Path]::GetRelativePath($CodexHome, $file.FullName)
        $target = Join-Path $destination $relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        Move-Item -LiteralPath $file.FullName -Destination $target
    }
}
[pscustomobject]@{ action = 'quarantine-stale-temp-files'; candidates = $candidates.Count; destination = $destination; applied = -not $WhatIfPreference } | ConvertTo-Json
