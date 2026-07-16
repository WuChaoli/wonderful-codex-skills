$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'plugins\fix-codex-retry-loop\skills\fix-codex-retry-loop\scripts\fix_codex_proxy.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fix-codex-retry-loop-test-" + [guid]::NewGuid().ToString('N'))
$passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    if (-not (Test-Path $scriptPath)) { throw "FAIL: implementation missing at $scriptPath" }

    $detectHome = Join-Path $testRoot 'detect-home'
    New-Item -ItemType Directory -Path $detectHome | Out-Null
    'HTTPS_PROXY=http://user:secret@127.0.0.1:7890' | Set-Content (Join-Path $detectHome '.env') -Encoding utf8
    $detect = (& pwsh -NoProfile -File $scriptPath -Action Detect -CodexHome $detectHome) | ConvertFrom-Json
    Assert-True ((Get-Content -Raw (Join-Path $detectHome '.env')) -match 'user:secret') 'Detect must not modify .env'
    Assert-True ($detect.existingProxy.HTTPS_PROXY -eq 'http://***@127.0.0.1:7890') 'Detect must redact credentials'

    $rejectHome = Join-Path $testRoot 'reject-home'
    New-Item -ItemType Directory -Path $rejectHome | Out-Null
    & pwsh -NoProfile -File $scriptPath -Action Apply -CodexHome $rejectHome -ProxyUrl 'http://127.0.0.1:7890' *> $null
    Assert-True ($LASTEXITCODE -ne 0 -and -not (Test-Path (Join-Path $rejectHome '.env'))) 'Apply without confirmation must not write'

    $applyHome = Join-Path $testRoot 'apply-home'
    New-Item -ItemType Directory -Path $applyHome | Out-Null
    $envPath = Join-Path $applyHome '.env'
    @('OPENAI_API_KEY=test-value', 'HTTP_PROXY=http://old.example:8080', 'CUSTOM_SETTING=keep-me') | Set-Content $envPath -Encoding utf8
    $apply = (& pwsh -NoProfile -File $scriptPath -Action Apply -CodexHome $applyHome -ProxyUrl 'http://127.0.0.1:7890' -ConfirmWrite) | ConvertFrom-Json
    $content = Get-Content -Raw $envPath
    Assert-True ($content -match 'OPENAI_API_KEY=test-value' -and $content -match 'CUSTOM_SETTING=keep-me') 'Apply must preserve unrelated variables'
    Assert-True ($content -match 'HTTP_PROXY=http://127\.0\.0\.1:7890' -and $content -match 'HTTPS_PROXY=http://127\.0\.0\.1:7890' -and $content -match 'NO_PROXY=localhost,127\.0\.0\.1,::1' -and (Test-Path $apply.backupPath)) 'Apply must update variables and create backup'
    Write-Output "PASS: $passed tests"
}
finally {
    if (Test-Path $testRoot) { Remove-Item $testRoot -Recurse -Force }
}
