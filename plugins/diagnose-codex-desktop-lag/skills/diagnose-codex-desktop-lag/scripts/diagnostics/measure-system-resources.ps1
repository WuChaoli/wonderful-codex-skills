[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$os = Get-CimInstance Win32_OperatingSystem
$drives = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    [pscustomobject]@{
        drive = $_.DeviceID
        size_gb = [math]::Round($_.Size / 1GB, 2)
        free_gb = [math]::Round($_.FreeSpace / 1GB, 2)
        free_percent = if ($_.Size) { [math]::Round(100 * $_.FreeSpace / $_.Size, 1) } else { $null }
    }
}

$freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$status = if ($freeGb -lt 2 -or @($drives | Where-Object { $_.free_percent -lt 10 }).Count) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'system-resources' -Status $status -Data @{
    logical_processors = [Environment]::ProcessorCount
    total_memory_gb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    free_memory_gb = $freeGb
    drives = @($drives)
} | Write-DiagnosticJson
