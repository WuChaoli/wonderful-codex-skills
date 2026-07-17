[CmdletBinding()]
param(
    [ValidateRange(2, 60)][int]$SampleSeconds = 10,
    [ValidateRange(200, 5000)][int]$PollMilliseconds = 500
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$seen = @{}
$started = Get-Date
do {
    $all = @(Get-CimInstance Win32_Process)
    $codexIds = [System.Collections.Generic.HashSet[int]]::new()
    $all | Where-Object {
        $_.Name -match '^(Codex|codex)(\.exe)?$' -or ($_.ExecutablePath -and $_.ExecutablePath -match '\\Codex\\')
    } | ForEach-Object { [void]$codexIds.Add([int]$_.ProcessId) }
    $frontier = @($codexIds)
    while ($frontier.Count) {
        $next = [System.Collections.Generic.List[int]]::new()
        foreach ($process in $all | Where-Object { $frontier -contains [int]$_.ParentProcessId }) {
            if ($codexIds.Add([int]$process.ProcessId)) {
                $next.Add([int]$process.ProcessId)
                $key = "$($process.ProcessId)|$($process.CreationDate)"
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = [pscustomobject]@{
                        pid = $process.ProcessId
                        parent_pid = $process.ParentProcessId
                        name = $process.Name
                        created = $process.CreationDate
                    }
                }
            }
        }
        $frontier = @($next)
    }
    if (((Get-Date) - $started).TotalSeconds -lt $SampleSeconds) { Start-Sleep -Milliseconds $PollMilliseconds }
} while (((Get-Date) - $started).TotalSeconds -lt $SampleSeconds)

$rows = @($seen.Values)
$suspicious = @($rows | Where-Object { $_.name -match '^(git|wsl|bash|powershell|pwsh|python)(\.exe)?$' })
$counts = @($suspicious | Group-Object name | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{ name = $_.Name; unique_processes = $_.Count }
})
$status = if ($suspicious.Count -ge 5) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'codex-child-processes' -Status $status -Data @{
    sample_seconds = $SampleSeconds
    descendants_seen = $rows
    suspicious_unique_processes = $suspicious.Count
    suspicious_by_name = $counts
} | Write-DiagnosticJson
