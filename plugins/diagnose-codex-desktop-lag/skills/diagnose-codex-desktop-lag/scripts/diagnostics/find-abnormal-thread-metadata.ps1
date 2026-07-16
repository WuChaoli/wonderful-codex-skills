[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(1000, 10000000)][int]$ThresholdChars = 100000,
    [ValidateRange(1, 200)][int]$Limit = 50
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'state_5.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'abnormal-thread-metadata' -Status 'skipped' -Data @{ path = $db } -Notes @('state_5.sqlite was not found.') | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, sqlite3, sys
p,threshold,limit=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
q="""select id,archived,tokens_used,length(title),length(first_user_message),length(preview),length(title)+length(first_user_message)+length(preview) as metadata_chars from threads where metadata_chars>=? order by metadata_chars desc limit ?"""
rows=[dict(thread_id=r[0],archived=r[1],tokens_used=r[2],title_chars=r[3],first_user_message_chars=r[4],preview_chars=r[5],metadata_chars=r[6]) for r in con.execute(q,(threshold,limit))]
print(json.dumps({"threshold_chars":threshold,"threads":rows}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db, [string]$ThresholdChars, [string]$Limit)
New-DiagnosticResult -Check 'abnormal-thread-metadata' -Status $(if (@($data.threads).Count) { 'warning' } else { 'ok' }) -Data $data | Write-DiagnosticJson
