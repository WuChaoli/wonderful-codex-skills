[CmdletBinding()]
param([string]$CodexHome = '')

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'state_5.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'state-database-integrity' -Status 'skipped' -Data @{ path = $db } -Notes @('state_5.sqlite was not found.') | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, sqlite3, sys
p=sys.argv[1]
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
result=con.execute("pragma integrity_check").fetchall()
fk=con.execute("pragma foreign_key_check").fetchall()
tables=[r[0] for r in con.execute("select name from sqlite_master where type='table' order by name")]
print(json.dumps({"integrity":[r[0] for r in result],"foreign_key_errors":fk,"tables":tables}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db)
$ok = @($data.integrity).Count -eq 1 -and $data.integrity[0] -eq 'ok' -and @($data.foreign_key_errors).Count -eq 0
New-DiagnosticResult -Check 'state-database-integrity' -Status $(if ($ok) { 'ok' } else { 'error' }) -Data $data | Write-DiagnosticJson
