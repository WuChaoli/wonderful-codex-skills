[CmdletBinding()]
param([string]$CodexHome = '')

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'logs_2.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'log-database-integrity' -Status 'skipped' -Data @{ path = $db } -Notes @('logs_2.sqlite was not found.') | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, sqlite3, sys
p=sys.argv[1]
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
integrity=[r[0] for r in con.execute("pragma integrity_check")]
tables=[r[0] for r in con.execute("select name from sqlite_master where type='table' order by name")]
triggers=[r[0] for r in con.execute("select name from sqlite_master where type='trigger' order by name")]
print(json.dumps({"integrity":integrity,"tables":tables,"triggers":triggers}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db)
$ok = @($data.integrity).Count -eq 1 -and $data.integrity[0] -eq 'ok'
New-DiagnosticResult -Check 'log-database-integrity' -Status $(if ($ok) { 'ok' } else { 'error' }) -Data $data | Write-DiagnosticJson
