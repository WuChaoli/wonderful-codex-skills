[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(1, 4096)][int]$ThresholdMB = 8,
    [ValidateRange(1, 200)][int]$Limit = 50
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'state_5.sqlite'
if (-not (Test-Path -LiteralPath $db)) {
    New-DiagnosticResult -Check 'large-rollout-files' -Status 'skipped' -Data @{ path = $db } -Notes @('state_5.sqlite was not found.') | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, os, sqlite3, sys
p,threshold,limit=sys.argv[1],int(sys.argv[2])*1024*1024,int(sys.argv[3])
con=sqlite3.connect(f"file:{p}?mode=ro", uri=True)
rows=[]
missing=0
for tid,path,archived,tokens in con.execute("select id,rollout_path,archived,tokens_used from threads"):
    if not os.path.isfile(path): missing+=1; continue
    size=os.path.getsize(path)
    if size>=threshold: rows.append({"thread_id":tid,"rollout_path":path,"size_bytes":size,"archived":archived,"tokens_used":tokens})
rows.sort(key=lambda x:x["size_bytes"],reverse=True)
print(json.dumps({"threshold_bytes":threshold,"matching_count":len(rows),"missing_rollout_paths":missing,"largest":rows[:limit]}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($db, [string]$ThresholdMB, [string]$Limit)
New-DiagnosticResult -Check 'large-rollout-files' -Status $(if ($data.matching_count -gt 0) { 'warning' } else { 'ok' }) -Data $data -Notes @('Uses rollout paths indexed by state_5.sqlite; it does not recursively scan the entire sessions tree.') | Write-DiagnosticJson
