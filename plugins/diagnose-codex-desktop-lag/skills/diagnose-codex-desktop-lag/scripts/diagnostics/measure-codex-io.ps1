[CmdletBinding()]
param(
    [ValidateRange(2, 60)][int]$SampleSeconds = 10
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$first = @{}
foreach ($process in Get-CodexProcessCim) {
    $first[$process.ProcessId] = @($process.ReadTransferCount, $process.WriteTransferCount)
}
Start-Sleep -Seconds $SampleSeconds

$rows = foreach ($process in Get-CodexProcessCim) {
    if ($first.ContainsKey($process.ProcessId)) {
        [pscustomobject]@{
            pid = $process.ProcessId
            name = $process.Name
            read_bytes_per_second = [math]::Round(($process.ReadTransferCount - $first[$process.ProcessId][0]) / $SampleSeconds, 1)
            write_bytes_per_second = [math]::Round(($process.WriteTransferCount - $first[$process.ProcessId][1]) / $SampleSeconds, 1)
        }
    }
}

New-DiagnosticResult -Check 'codex-process-io' -Status 'ok' -Data @{
    sample_seconds = $SampleSeconds
    processes = @($rows)
} | Write-DiagnosticJson
