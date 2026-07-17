[CmdletBinding()]
param([string]$CodexHome = '')

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'state_5.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'thread-state-summary' -Status 'skipped' -Data @{ path = $db } -Notes @('state_5.sqlite was not found.') | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, sqlite3, sys
p=sys.argv[1]
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
cols={r[1] for r in con.execute("pragma table_info(threads)")}
needed={"archived","tokens_used","source","title","first_user_message","preview"}
if not needed.issubset(cols):
    print(json.dumps({"schema_supported":False,"columns":sorted(cols)})); raise SystemExit
q="""select
count(*),
sum(case when archived=0 then 1 else 0 end),
sum(case when archived=1 then 1 else 0 end),
sum(case when archived=0 and tokens_used>=1000000 then 1 else 0 end),
sum(case when archived=0 and tokens_used>=10000000 then 1 else 0 end),
sum(case when archived=0 and tokens_used>=100000000 then 1 else 0 end),
sum(case when archived=0 then length(title)+length(first_user_message)+length(preview) else 0 end)
from threads"""
r=con.execute(q).fetchone()
sources=[dict(source=x[0],active=x[1]) for x in con.execute("select source,count(*) from threads where archived=0 group by source order by count(*) desc")]
print(json.dumps({"schema_supported":True,"total":r[0],"active":r[1] or 0,"archived":r[2] or 0,"active_tokens_ge_1m":r[3] or 0,"active_tokens_ge_10m":r[4] or 0,"active_tokens_ge_100m":r[5] or 0,"active_metadata_chars":r[6] or 0,"active_by_source":sources}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db)
$status = if (-not $data.schema_supported) { 'skipped' } elseif ($data.active -gt 500 -or $data.active_tokens_ge_100m -gt 0) { 'warning' } else { 'ok' }
New-DiagnosticResult -Check 'thread-state-summary' -Status $status -Data $data | Write-DiagnosticJson
