[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(1, 1440)][int]$WindowMinutes = 30
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'logs_2.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'log-level-summary' -Status 'skipped' -Data @{ path = $db } | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, sqlite3, sys, time
p,minutes=sys.argv[1],int(sys.argv[2])
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
cols={r[1] for r in con.execute("pragma table_info(logs)")}
if not {"ts","level","target"}.issubset(cols):
    print(json.dumps({"schema_supported":False,"columns":sorted(cols)})); raise SystemExit
cutoff=int(time.time())-minutes*60
levels=[dict(level=r[0],rows=r[1],estimated_bytes=r[2] or 0) for r in con.execute("select level,count(*),sum(estimated_bytes) from logs where ts>=? group by level order by count(*) desc",(cutoff,))]
targets=[dict(target=r[0],level=r[1],rows=r[2],estimated_bytes=r[3] or 0) for r in con.execute("select target,level,count(*),sum(estimated_bytes) from logs where ts>=? group by target,level order by estimated_bytes desc limit 20",(cutoff,))]
print(json.dumps({"schema_supported":True,"window_minutes":minutes,"levels":levels,"top_targets":targets}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db, [string]$WindowMinutes)
$trace = @($data.levels | Where-Object { $_.level -eq 'TRACE' } | Select-Object -First 1)
$allBytes = ($data.levels | Measure-Object estimated_bytes -Sum).Sum
$traceRatio = if ($allBytes -and $trace) { $trace[0].estimated_bytes / $allBytes } else { 0 }
$status = if (-not $data.schema_supported) { 'skipped' } elseif ($traceRatio -gt 0.8) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'log-level-summary' -Status $status -Data $data | Write-DiagnosticJson
