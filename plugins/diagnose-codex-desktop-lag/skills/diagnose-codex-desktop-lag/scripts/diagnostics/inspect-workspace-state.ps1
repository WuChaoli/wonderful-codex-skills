[CmdletBinding()]
param(
    [string]$CodexHome = '',
    [ValidateRange(1, 500)][int]$Limit = 100
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$state = Join-Path $CodexHome '.codex-global-state.json'
if (-not (Test-Path -LiteralPath $state)) {
    New-DiagnosticResult -Check 'workspace-state' -Status 'skipped' -Data @{ path = $state } | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, os, re, sys
p,limit=sys.argv[1],int(sys.argv[2])
with open(p,'r',encoding='utf-8') as f: data=json.load(f)
found=[]
def walk(value,keypath='$'):
    if len(found)>=limit: return
    if isinstance(value,dict):
        for k,v in value.items(): walk(v,f'{keypath}.{k}')
    elif isinstance(value,list):
        for i,v in enumerate(value): walk(v,f'{keypath}[{i}]')
    elif isinstance(value,str):
        looks_path=bool(re.search(r'^[A-Za-z]:[\\/]|^/[^/]',value))
        if looks_path and any(x in keypath.lower() for x in ('project','workspace','cwd','path','root')):
            found.append({'json_path':keypath,'value':value,'exists':os.path.exists(value)})
walk(data)
print(json.dumps({'file_bytes':os.path.getsize(p),'top_level_keys':sorted(data.keys()) if isinstance(data,dict) else [],'path_candidates':found,'truncated':len(found)>=limit}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($state, [string]$Limit)
$stale = @($data.path_candidates | Where-Object { -not $_.exists })
New-DiagnosticResult -Check 'workspace-state' -Status $(if ($stale.Count) { 'warning' } else { 'ok' }) -Data $data -Notes @('Inspect candidates only. Do not remove a workspace path or its physical directory during diagnosis.') | Write-DiagnosticJson
