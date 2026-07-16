[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$processes = Get-CodexProcessCim
$versions = foreach ($process in $processes) {
    $version = if ($process.ExecutablePath -and (Test-Path -LiteralPath $process.ExecutablePath)) {
        (Get-Item -LiteralPath $process.ExecutablePath).VersionInfo.ProductVersion
    }
    [pscustomobject]@{ pid = $process.ProcessId; executable = $process.Name; version = $version }
}

$packages = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Codex' } |
    Select-Object Name, Version, PackageFullName

New-DiagnosticResult -Check 'codex-version' -Status 'ok' -Data @{
    running_processes = @($versions)
    appx_packages = @($packages)
    windows = [Environment]::OSVersion.VersionString
} | Write-DiagnosticJson
