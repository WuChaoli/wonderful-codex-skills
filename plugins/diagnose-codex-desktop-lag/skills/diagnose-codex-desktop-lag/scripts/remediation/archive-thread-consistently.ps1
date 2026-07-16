[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F-]{20,}$')][string]$ThreadId,
    [string]$CodexHome = ''
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'state_5.sqlite'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $CodexHome "performance-backups/thread-archive-$stamp-$ThreadId"
$quarantineDir = Join-Path $CodexHome "performance-quarantine/threads/$stamp/$ThreadId"
$code = @'
import json, os, shutil, sqlite3, sys, time
db,tid,backup_dir,quarantine_dir=sys.argv[1:5]
os.makedirs(backup_dir,exist_ok=True)
backup=os.path.join(backup_dir,'state_5.sqlite')
src=sqlite3.connect(f"file:{db}?mode=ro",uri=True); dst=sqlite3.connect(backup); src.backup(dst); dst.close(); src.close()
con=sqlite3.connect(db)
row=con.execute('select rollout_path,archived,archived_at from threads where id=?',(tid,)).fetchone()
if not row: raise RuntimeError('thread not found')
source=os.path.abspath(row[0])
source_key=os.path.normcase(source)
sessions=os.path.normcase(os.path.abspath(os.path.join(os.path.dirname(db),'sessions'))+os.sep)
archived_sessions=os.path.normcase(os.path.abspath(os.path.join(os.path.dirname(db),'archived_sessions'))+os.sep)
if not (source_key.startswith(sessions) or source_key.startswith(archived_sessions)):
    raise RuntimeError('rollout path is outside the active Codex session roots')
if not os.path.isfile(source): raise RuntimeError('rollout file not found')
os.makedirs(quarantine_dir,exist_ok=True)
destination=os.path.join(quarantine_dir,os.path.basename(source))
if os.path.exists(destination): raise RuntimeError('quarantine destination already exists')
shutil.move(source,destination)
try:
    con.execute('begin immediate')
    con.execute('update threads set archived=1, archived_at=?, rollout_path=? where id=?',(int(time.time()*1000),destination,tid))
    con.commit()
    integrity=con.execute('pragma integrity_check').fetchone()[0]
    if integrity!='ok': raise RuntimeError('integrity_check failed: '+integrity)
except Exception:
    con.rollback()
    if os.path.exists(destination) and not os.path.exists(source):
        os.makedirs(os.path.dirname(source),exist_ok=True); shutil.move(destination,source)
    raise
finally:
    con.close()
manifest={'thread_id':tid,'source':source,'destination':destination,'database_backup':backup,'previous_archived':row[1],'previous_archived_at':row[2]}
with open(os.path.join(backup_dir,'archive-manifest.json'),'w',encoding='utf-8') as f: json.dump(manifest,f,ensure_ascii=False,indent=2)
print(json.dumps(manifest))
'@

$result = $null
if ($PSCmdlet.ShouldProcess($ThreadId, "Back up state_5.sqlite, move one rollout to quarantine, and archive only this thread")) {
    Assert-CodexStopped
    $result = Invoke-PythonJson -Code $code -ArgumentList @($db, $ThreadId, $backupDir, $quarantineDir)
}
[pscustomobject]@{ action = 'archive-thread-consistently'; thread_id = $ThreadId; backup_directory = $backupDir; quarantine_directory = $quarantineDir; result = $result; applied = -not $WhatIfPreference; verification = 'Restart Codex, then rerun summarize-thread-state.ps1 and find-large-rollout-files.ps1.' } | ConvertTo-Json -Depth 6
