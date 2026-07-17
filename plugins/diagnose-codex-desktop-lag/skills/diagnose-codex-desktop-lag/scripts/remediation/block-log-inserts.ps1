[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$CodexHome = '',
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')][string]$TriggerName = 'block_log_inserts'
)

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force
if (-not $CodexHome) { $CodexHome = Get-CodexHomePath }
$db = Join-Path $CodexHome 'logs_2.sqlite'
if (-not (Test-Path -LiteralPath $db)) { throw 'logs_2.sqlite was not found.' }
$backupDir = Join-Path $CodexHome ('performance-backups/log-trigger-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$backup = Join-Path $backupDir 'logs_2.sqlite'
$code = @'
import json, os, sqlite3, sys
p,backup,name=sys.argv[1:4]
os.makedirs(os.path.dirname(backup),exist_ok=True)
src=sqlite3.connect(f"file:{p}?mode=ro",uri=True); dst=sqlite3.connect(backup); src.backup(dst); dst.close(); src.close()
con=sqlite3.connect(p)
tables={r[0] for r in con.execute("select name from sqlite_master where type='table'")}
if 'logs' not in tables: raise RuntimeError('logs table not found')
existing=con.execute("select sql from sqlite_master where type='trigger' and name=?",(name,)).fetchone()
if not existing:
    con.execute(f'create trigger "{name}" before insert on logs begin select raise(ignore); end')
    con.commit()
integrity=con.execute('pragma integrity_check').fetchone()[0]
con.close()
print(json.dumps({'created':not bool(existing),'already_existed':bool(existing),'backup':backup,'integrity':integrity}))
'@
$result = $null
if ($PSCmdlet.ShouldProcess($db, "Back up database and create reversible trigger '$TriggerName'")) {
    Assert-CodexStopped
    $result = Invoke-PythonJson -Code $code -ArgumentList @($db, $backup, $TriggerName)
}
[pscustomobject]@{ action = 'block-log-inserts'; database = $db; trigger = $TriggerName; result = $result; applied = -not $WhatIfPreference } | ConvertTo-Json -Depth 5
