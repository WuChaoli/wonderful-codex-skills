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

Write-Output "PASS: $passed repository checks"
