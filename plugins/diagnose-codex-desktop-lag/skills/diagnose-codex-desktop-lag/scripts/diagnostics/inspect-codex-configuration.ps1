[CmdletBinding()]
param([string]$CodexHome = '')

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$config = Join-Path $CodexHome 'config.toml'
if (-not (Test-Path -LiteralPath $config)) {
    New-DiagnosticResult -Check 'codex-configuration' -Status 'skipped' -Data @{ path = $config } | Write-DiagnosticJson
    exit 0
}

$code = @'
import json, os, sys, tomllib
p=sys.argv[1]
with open(p,'rb') as f: data=tomllib.load(f)
features=data.get('features',{})
safe_features={k:v for k,v in features.items() if isinstance(v,(str,int,float,bool))}
projects=data.get('projects',{})
project_rows=[]
for path,value in projects.items():
    project_rows.append({'path':path,'exists':os.path.exists(path),'trust_level':value.get('trust_level') if isinstance(value,dict) else None})
print(json.dumps({'file_bytes':os.path.getsize(p),'features':safe_features,'projects':project_rows,'show_context_window_usage':data.get('show-context-window-usage')}))
'@
$data = Invoke-PythonJson -Code $code -ArgumentList @($config)
New-DiagnosticResult -Check 'codex-configuration' -Status 'ok' -Data $data -Notes @('Authentication, tokens, and provider secrets are intentionally omitted.') | Write-DiagnosticJson
