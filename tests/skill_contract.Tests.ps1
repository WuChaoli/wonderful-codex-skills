$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$skillPath = Join-Path $repoRoot 'plugins\fix-codex-retry-loop\skills\fix-codex-retry-loop\SKILL.md'
if (-not (Test-Path $skillPath)) { throw "FAIL: skill missing at $skillPath" }
$content = Get-Content -Raw $skillPath
$requiredPatterns = [ordered]@{
    trigger = 'description:\s*Use when'
    detection = '-Action Detect'
    confirmation = '明确确认'
    guard = '-ConfirmWrite'
    home = 'CODEX_HOME'
    backup = '备份'
    reachability = '401'
    restart = '完全退出.*Codex.*重新启动'
    rollback = '回滚'
}
$passed = 0
foreach ($entry in $requiredPatterns.GetEnumerator()) {
    if ($content -notmatch $entry.Value) { throw "FAIL: SKILL.md missing contract: $($entry.Key)" }
    $passed++
}
if ($content -match 'TODO|TBD') { throw 'FAIL: SKILL.md contains placeholders' }
Write-Output "PASS: $passed skill contract checks"
