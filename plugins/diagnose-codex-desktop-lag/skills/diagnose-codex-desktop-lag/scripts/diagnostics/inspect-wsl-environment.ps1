[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$names = @('WSL_DISTRO_NAME', 'WSL_INTEROP', 'WSLENV')
$rows = foreach ($name in $names) {
    [pscustomobject]@{
        name = $name
        process = [Environment]::GetEnvironmentVariable($name, 'Process')
        user = [Environment]::GetEnvironmentVariable($name, 'User')
        machine = [Environment]::GetEnvironmentVariable($name, 'Machine')
    }
}
$marker = $rows | Where-Object { $_.name -eq 'WSL_DISTRO_NAME' -and ($_.process -or $_.user -or $_.machine) }
$status = if ($marker) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'wsl-environment' -Status $status -Data @{ variables = @($rows) } -Notes @(
    if ($marker) { 'WSL_DISTRO_NAME is present in a Windows-native process environment; confirm whether Codex is invoking wsl.exe.' }
) | Write-DiagnosticJson
