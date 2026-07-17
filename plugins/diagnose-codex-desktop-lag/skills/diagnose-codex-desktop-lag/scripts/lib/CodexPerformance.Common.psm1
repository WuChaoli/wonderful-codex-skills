Set-StrictMode -Version Latest

function Get-CodexHomePath {
    if ($env:CODEX_HOME) {
        return [IO.Path]::GetFullPath($env:CODEX_HOME)
    }
    return [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE '.codex'))
}

function Get-PythonCommand {
    foreach ($name in @('python', 'py')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'Python 3 is required for SQLite and JSON diagnostics.'
}

function Invoke-PythonJson {
    param(
        [Parameter(Mandatory)][string]$Code,
        [string[]]$ArgumentList = @()
    )
    $python = Get-PythonCommand
    $output = & $python -c $Code @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "Python command failed with exit code $LASTEXITCODE." }
    return ($output | ConvertFrom-Json)
}

function New-DiagnosticResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('ok','warning','error','skipped')][string]$Status,
        [object]$Data,
        [string[]]$Notes = @()
    )
    [pscustomobject]@{
        check = $Check
        status = $Status
        timestamp = (Get-Date).ToString('o')
        data = $Data
        notes = $Notes
    }
}

function Write-DiagnosticJson {
    param([Parameter(ValueFromPipeline, Mandatory)][object]$InputObject)
    process { $InputObject | ConvertTo-Json -Depth 12 }
}

function Get-CodexProcessCim {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(Codex|codex)(\.exe)?$' -or
        ($_.ExecutablePath -and $_.ExecutablePath -match '\\Codex\\')
    }
}

function Assert-CodexStopped {
    if (Get-CodexProcessCim) {
        throw 'Codex Desktop or codex.exe is still running. Exit it before applying this repair.'
    }
}

function Assert-PathUnderRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )
    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if (-not $resolvedPath.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the allowed root: $resolvedPath"
    }
    return $resolvedPath
}

function New-TimestampedDirectory {
    param(
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Prefix
    )
    $path = Join-Path $Parent ($Prefix + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [IO.Directory]::CreateDirectory($path) | Out-Null
    return $path
}

function Backup-SqliteDatabase {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $code = @'
import sqlite3, sys
src,dst=sys.argv[1],sys.argv[2]
source=sqlite3.connect(f"file:{src}?mode=ro", uri=True)
target=sqlite3.connect(dst)
source.backup(target)
target.close(); source.close()
'@
    $python = Get-PythonCommand
    & $python -c $code $Source $Destination
    if ($LASTEXITCODE -ne 0) { throw "SQLite backup failed for $Source." }
}

Export-ModuleMember -Function *
