[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$pids = @(Get-CodexProcessCim | ForEach-Object { [int]$_.ProcessId })
if (-not $pids.Count) {
    New-DiagnosticResult -Check 'codex-gpu' -Status 'skipped' -Data @{} -Notes @('No Codex process is running.') | Write-DiagnosticJson
    exit 0
}

try {
    $samples = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
    $rows = $samples.CounterSamples | Where-Object {
        $path = $_.Path
        $pids | Where-Object { $path -match "pid_$($_)_" }
    } | ForEach-Object {
        [pscustomobject]@{ instance = $_.InstanceName; utilization_percent = [math]::Round($_.CookedValue, 2) }
    }
    New-DiagnosticResult -Check 'codex-gpu' -Status 'ok' -Data @{ engines = @($rows) } | Write-DiagnosticJson
} catch {
    New-DiagnosticResult -Check 'codex-gpu' -Status 'skipped' -Data @{} -Notes @($_.Exception.Message) | Write-DiagnosticJson
}
