[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$WorkspacePath,
    [string]$CodexHome = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$state = Join-Path $CodexHome '.codex-global-state.json'
if (-not (Test-Path -LiteralPath $state)) { throw '.codex-global-state.json was not found.' }
$backupDir = Join-Path $CodexHome ('performance-backups/workspace-state-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$backup = Join-Path $backupDir '.codex-global-state.json'
$code = @'
import json, os, shutil, sys, tempfile
p,target,backup=sys.argv[1:4]
os.makedirs(os.path.dirname(backup),exist_ok=True)
shutil.copy2(p,backup)
with open(p,'r',encoding='utf-8') as f: data=json.load(f)
changed=[]
for key in ('electron-saved-workspace-roots','active-workspace-roots','project-order','pinned-project-ids'):
    value=data.get(key)
    if isinstance(value,list):
        new=[x for x in value if not (isinstance(x,str) and os.path.normcase(os.path.normpath(x))==os.path.normcase(os.path.normpath(target)))]
        if len(new)!=len(value): data[key]=new; changed.append(key)
labels=data.get('electron-workspace-root-labels')
if isinstance(labels,dict):
    for key in list(labels):
        if os.path.normcase(os.path.normpath(key))==os.path.normcase(os.path.normpath(target)):
            del labels[key]; changed.append('electron-workspace-root-labels')
fd,tmp=tempfile.mkstemp(prefix='.codex-global-state.',suffix='.tmp',dir=os.path.dirname(p))
try:
    with os.fdopen(fd,'w',encoding='utf-8',newline='') as f: json.dump(data,f,ensure_ascii=False,separators=(',',':'))
    os.replace(tmp,p)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print(json.dumps({'changed_keys':changed,'backup':backup}))
'@

$data = $null
if ($PSCmdlet.ShouldProcess($state, "Remove only the exact workspace entry '$WorkspacePath'; do not touch the physical directory")) {
    Assert-CodexStopped
    $data = Invoke-PythonJson -Code $code -ArgumentList @($state, $WorkspacePath, $backup)
}
[pscustomobject]@{ action = 'remove-stale-workspace-state'; workspace = $WorkspacePath; preview_keys = @('electron-saved-workspace-roots','active-workspace-roots','project-order','pinned-project-ids','electron-workspace-root-labels'); result = $data; applied = -not $WhatIfPreference } | ConvertTo-Json -Depth 5
