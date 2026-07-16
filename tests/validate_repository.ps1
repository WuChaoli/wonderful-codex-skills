$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$marketplacePath = Join-Path $repoRoot '.agents\plugins\marketplace.json'
$pluginRoot = Join-Path $repoRoot 'plugins\fix-codex-retry-loop'
$manifestPath = Join-Path $pluginRoot '.codex-plugin\plugin.json'
$passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
}

Assert-True (Test-Path $marketplacePath) 'marketplace.json must exist'
Assert-True (Test-Path $manifestPath) 'plugin.json must exist'

$marketplace = Get-Content -Raw $marketplacePath | ConvertFrom-Json
$entry = $marketplace.plugins | Where-Object name -eq 'fix-codex-retry-loop'
Assert-True ($marketplace.name -eq 'wonderful-codex-skills') 'marketplace name must be stable'
Assert-True ($marketplace.interface.displayName -eq 'Wonderful Codex Skills') 'marketplace display name must match'
Assert-True ($entry.source.path -eq './plugins/fix-codex-retry-loop') 'plugin source path must be repository-relative'
Assert-True ($entry.category -eq 'Codex Tools') 'plugin must be categorized as Codex Tools'
Assert-True ($entry.policy.installation -eq 'AVAILABLE' -and $entry.policy.authentication -eq 'ON_INSTALL') 'marketplace policy must be explicit'

$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
Assert-True ($manifest.name -eq 'fix-codex-retry-loop') 'manifest name must match folder'
Assert-True ($manifest.version -eq '0.1.0') 'manifest version must be 0.1.0'
Assert-True ($manifest.skills -eq './skills/') 'manifest must point to skills directory'
Assert-True ($manifest.license -eq 'MIT') 'manifest license must be MIT'

$publicFiles = Get-ChildItem -Recurse -File $repoRoot | Where-Object FullName -NotMatch '\\.git\\'
Assert-True (-not ($publicFiles | Where-Object Name -Match '^\.env($|\.)')) 'repository must not contain .env or backups'
$localUser = 'wucha' + 'oli'
$githubTokenPrefix = 'github' + '_pat_'
$openAiKeyPattern = 's' + 'k-[A-Za-z0-9_-]{20,}'
$sensitiveHits = $publicFiles | Select-String -Pattern "C:\\Users\\$localUser|$githubTokenPrefix|$openAiKeyPattern" -ErrorAction SilentlyContinue
Assert-True (-not $sensitiveHits) 'repository must not contain machine paths or common secret patterns'

$readmePath = Join-Path $repoRoot 'README.md'
$contributingPath = Join-Path $repoRoot 'CONTRIBUTING.md'
$licensePath = Join-Path $repoRoot 'LICENSE'
$workflowPath = Join-Path $repoRoot '.github\workflows\validate.yml'
Assert-True (Test-Path $readmePath) 'README.md must exist'
Assert-True (Test-Path $contributingPath) 'CONTRIBUTING.md must exist'
Assert-True (Test-Path $licensePath) 'LICENSE must exist'
Assert-True (Test-Path $workflowPath) 'Windows validation workflow must exist'

$readme = Get-Content -Raw $readmePath
Assert-True ($readme -match 'codex plugin marketplace add WuChaoli/wonderful-codex-skills') 'README must include the install command'
foreach ($category in @('Codex Tools', 'Development', 'Design', 'Productivity', 'Other')) {
    Assert-True ($readme -match [regex]::Escape($category)) "README must list category $category"
}

$pluginReadmePath = Join-Path $pluginRoot 'README.md'
Assert-True (Test-Path $pluginReadmePath) 'plugin README must exist'
Assert-True ($readme -match [regex]::Escape('plugins/fix-codex-retry-loop/README.md')) 'root README must link to plugin README'
$pluginReadme = Get-Content -Raw $pluginReadmePath
$guideContracts = [ordered]@{
    install = 'codex plugin marketplace add WuChaoli/wonderful-codex-skills'
    invoke = '\$fix-codex-retry-loop'
    windows = 'Windows'
    confirmation = '明确确认'
    backup = '备份'
    restart = '完全.*重启 Codex'
    reachability = '401'
    rateLimit = '429'
    serverError = '5xx'
    upgrade = 'codex plugin marketplace upgrade wonderful-codex-skills'
    uninstall = '卸载'
    rollback = '回滚'
}
foreach ($contract in $guideContracts.GetEnumerator()) {
    Assert-True ($pluginReadme -match $contract.Value) "plugin README must document $($contract.Key)"
}

$workflow = Get-Content -Raw $workflowPath
foreach ($testName in @('validate_repository.ps1', 'fix_codex_proxy.Tests.ps1', 'skill_contract.Tests.ps1')) {
    Assert-True ($workflow -match [regex]::Escape($testName)) "CI must run $testName"
}

Write-Output "PASS: $passed repository checks"
