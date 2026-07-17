[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('User', 'Machine')][string]$Scope = 'User'
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
$name = 'WSL_DISTRO_NAME'
$old = [Environment]::GetEnvironmentVariable($name, $Scope)
if ($PSCmdlet.ShouldProcess("$Scope environment variable $name", "Remove value '$old'")) {
    Assert-CodexStopped
    [Environment]::SetEnvironmentVariable($name, $null, $Scope)
}
[pscustomobject]@{ action = 'remove-wsl-environment-marker'; scope = $Scope; previous_value = $old; applied = -not $WhatIfPreference; note = 'Sign out or restart Windows before judging the result.' } | ConvertTo-Json
