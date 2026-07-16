$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$pluginRoot = Join-Path $repoRoot 'plugins\diagnose-codex-desktop-lag'
$skillRoot = Join-Path $pluginRoot 'skills\diagnose-codex-desktop-lag'
$passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
}

$manifest = Get-Content -Raw (Join-Path $pluginRoot '.codex-plugin\plugin.json') | ConvertFrom-Json
$skill = Get-Content -Raw (Join-Path $skillRoot 'SKILL.md')
$diagnostics = @(Get-ChildItem (Join-Path $skillRoot 'scripts\diagnostics') -Filter '*.ps1')
$remediations = @(Get-ChildItem (Join-Path $skillRoot 'scripts\remediation') -Filter '*.ps1')

Assert-True ($manifest.name -eq 'diagnose-codex-desktop-lag') 'manifest name must match folder'
Assert-True ($manifest.version -eq '0.1.0') 'manifest version must be 0.1.0'
Assert-True ($manifest.skills -eq './skills/') 'manifest must point to skills directory'
Assert-True ($skill -match '(?m)^description: Use when Windows Codex Desktop') 'skill must expose concrete triggers'
Assert-True ($skill -match '(?m)^version: 0\.1\.0$') 'skill version must match manifest'
Assert-True ($skill -match '一次只执行一项修复') 'skill must enforce one repair at a time'
Assert-True ($skill -match '不派发子智能体') 'skill must remain inline'
Assert-True ($skill -match 'show-context-window-usage') 'skill must preserve requested context usage display'
Assert-True ($skill -match 'codespace') 'skill must protect physical project directories'
Assert-True ($diagnostics.Count -eq 18) 'skill must contain 18 independent diagnostic scripts'
Assert-True ($remediations.Count -eq 10) 'skill must contain 10 independent remediation scripts'

$parseErrors = @()
foreach ($file in @($diagnostics + $remediations + (Get-ChildItem (Join-Path $skillRoot 'scripts\lib') -Filter '*.psm1'))) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    $parseErrors += @($errors)
}
Assert-True ($parseErrors.Count -eq 0) 'all PowerShell scripts must parse'

foreach ($file in $diagnostics) {
    $content = Get-Content -Raw $file.FullName
    Assert-True ($content -notmatch '(?i)Remove-Item|Move-Item|Set-Content|Add-Content|CREATE\s+TRIGGER|\bUPDATE\s+threads\b') "diagnostic must remain read-only: $($file.Name)"
}
foreach ($file in $remediations) {
    $content = Get-Content -Raw $file.FullName
    Assert-True ($content -match 'SupportsShouldProcess\s*=\s*\$true') "remediation must support -WhatIf: $($file.Name)"
}

$publicFiles = Get-ChildItem -Recurse -File $pluginRoot
$localUser = 'wucha' + 'oli'
$githubTokenPrefix = 'github' + '_pat_'
$openAiKeyPattern = 's' + 'k-[A-Za-z0-9_-]{20,}'
$sensitive = $publicFiles | Select-String -Pattern "C:\\Users\\$localUser|$githubTokenPrefix|$openAiKeyPattern" -ErrorAction SilentlyContinue
Assert-True (-not $sensitive) 'plugin must not contain machine paths or credentials'

Write-Output "PASS: $passed diagnose-codex-desktop-lag checks"
