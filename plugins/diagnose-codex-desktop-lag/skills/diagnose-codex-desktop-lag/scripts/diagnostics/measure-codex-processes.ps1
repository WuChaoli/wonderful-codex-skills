[CmdletBinding()]
param(
    [ValidateRange(2, 60)][int]$SampleSeconds = 10
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$first = @{}
foreach ($process in Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^codex$' }) {
    $first[$process.Id] = $process.TotalProcessorTime.TotalSeconds
}
Start-Sleep -Seconds $SampleSeconds

$rows = foreach ($process in Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^codex$' }) {
    $before = $first[$process.Id]
    $cpuPercent = if ($null -ne $before) {
        100 * ($process.TotalProcessorTime.TotalSeconds - $before) / $SampleSeconds
    } else { $null }
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)"
    $role = if ($cim.CommandLine -match '--type=([^\s]+)') { $Matches[1] } else { 'main-or-app-server' }
    [pscustomobject]@{
        pid = $process.Id
        role = $role
        cpu_percent_of_one_logical_core = if ($null -ne $cpuPercent) { [math]::Round($cpuPercent, 2) } else { $null }
        working_set_mb = [math]::Round($process.WorkingSet64 / 1MB, 1)
        private_memory_mb = [math]::Round($process.PrivateMemorySize64 / 1MB, 1)
    }
}

$status = if (@($rows | Where-Object { $_.cpu_percent_of_one_logical_core -ge 50 }).Count) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'codex-process-cpu-memory' -Status $status -Data @{
    sample_seconds = $SampleSeconds
    processes = @($rows)
} | Write-DiagnosticJson
