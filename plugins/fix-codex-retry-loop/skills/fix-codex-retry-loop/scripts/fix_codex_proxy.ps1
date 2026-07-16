[CmdletBinding()]
param(
    [ValidateSet('Detect', 'Apply', 'Verify')]
    [string]$Action = 'Detect',

    [uri]$ProxyUrl,

    [string]$CodexHome,

    [switch]$ConfirmWrite
)

$ErrorActionPreference = 'Stop'

function Get-CodexHomePath {
    if ($CodexHome) {
        return [System.IO.Path]::GetFullPath($CodexHome)
    }
    if ($env:CODEX_HOME) {
        return [System.IO.Path]::GetFullPath($env:CODEX_HOME)
    }
    if (-not $env:USERPROFILE) {
        throw '无法确定 Codex Home：USERPROFILE 和 CODEX_HOME 均未设置。'
    }
    return Join-Path $env:USERPROFILE '.codex'
}

function Get-EnvProxyValues {
    param([string]$EnvPath)

    $values = [ordered]@{}
    if (-not (Test-Path -LiteralPath $EnvPath)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $EnvPath) {
        if ($line -match '^\s*(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)\s*=\s*(.*)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if ($value -match '^(https?://)[^/@]+@(.+)$') {
                $value = "$($Matches[1])***@$($Matches[2])"
            }
            $values[$key] = $value
        }
    }
    return $values
}

function Get-WindowsProxy {
    $settings = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if (-not $settings) {
        return $null
    }
    return [pscustomobject]@{
        enabled = [bool]$settings.ProxyEnable
        server = $settings.ProxyServer
        autoConfigUrl = $settings.AutoConfigURL
    }
}

function Get-ProxyListeners {
    $proxyNames = 'clash|mihomo|v2ray|xray|sing-box|nekoray|shadowsocks|proxifier|hiddify'
    $processes = @{}
    foreach ($process in Get-Process -ErrorAction SilentlyContinue) {
        if ($process.ProcessName -match $proxyNames) {
            $processes[[string]$process.Id] = $process.ProcessName
        }
    }

    $listeners = foreach ($listener in Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue) {
        $processId = [string]$listener.OwningProcess
        if ($processes.ContainsKey($processId)) {
            [pscustomobject]@{
                address = $listener.LocalAddress
                port = $listener.LocalPort
                processId = $listener.OwningProcess
                processName = $processes[$processId]
            }
        }
    }
    return @($listeners | Sort-Object port -Unique)
}

function Assert-ValidProxyUrl {
    if (-not $ProxyUrl) {
        throw 'Apply 和 Verify 操作必须提供 -ProxyUrl。'
    }
    if ($ProxyUrl.Scheme -notin @('http', 'https')) {
        throw '仅支持 http:// 或 https:// 代理地址。Windows 上优先使用代理软件的 HTTP/Mixed 端口。'
    }
    if (-not [string]::IsNullOrEmpty($ProxyUrl.UserInfo)) {
        throw '不允许把含用户名或密码的代理 URL 写入 Codex .env。'
    }
}

function Invoke-Detect {
    $homePath = Get-CodexHomePath
    $envPath = Join-Path $homePath '.env'
    [pscustomobject]@{
        action = 'Detect'
        platform = 'Windows'
        codexHome = $homePath
        envPath = $envPath
        envExists = Test-Path -LiteralPath $envPath
        existingProxy = Get-EnvProxyValues -EnvPath $envPath
        windowsProxy = Get-WindowsProxy
        listeners = Get-ProxyListeners
    } | ConvertTo-Json -Depth 6
}

function Invoke-Apply {
    Assert-ValidProxyUrl
    if (-not $ConfirmWrite) {
        throw '拒绝写入：必须在用户明确确认后传递 -ConfirmWrite。'
    }

    $homePath = Get-CodexHomePath
    $envPath = Join-Path $homePath '.env'
    New-Item -ItemType Directory -Path $homePath -Force | Out-Null

    $backupPath = $null
    $keptLines = @()
    if (Test-Path -LiteralPath $envPath) {
        $backupPath = "$envPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmssfff')"
        Copy-Item -LiteralPath $envPath -Destination $backupPath
        $keptLines = @(Get-Content -LiteralPath $envPath | Where-Object {
            $_ -notmatch '^\s*(?i:HTTP_PROXY|HTTPS_PROXY|NO_PROXY)\s*='
        })
    }

    while ($keptLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($keptLines[-1])) {
        $keptLines = @($keptLines | Select-Object -First ($keptLines.Count - 1))
    }

    $newLines = @($keptLines)
    if ($newLines.Count -gt 0) { $newLines += '' }
    $proxyValue = $ProxyUrl.AbsoluteUri.TrimEnd('/')
    $newLines += "HTTP_PROXY=$proxyValue"
    $newLines += "HTTPS_PROXY=$proxyValue"
    $newLines += 'NO_PROXY=localhost,127.0.0.1,::1'

    $tempPath = "$envPath.tmp-$([guid]::NewGuid().ToString('N'))"
    try {
        $newLines | Set-Content -LiteralPath $tempPath -Encoding utf8
        Move-Item -LiteralPath $tempPath -Destination $envPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }

    [pscustomobject]@{
        action = 'Apply'
        envPath = $envPath
        backupPath = $backupPath
        proxyUrl = $proxyValue
        restartRequired = $true
    } | ConvertTo-Json -Depth 4
}

function Invoke-Verify {
    Assert-ValidProxyUrl
    $port = if ($ProxyUrl.IsDefaultPort) {
        if ($ProxyUrl.Scheme -eq 'https') { 443 } else { 80 }
    } else {
        $ProxyUrl.Port
    }

    $portReachable = Test-NetConnection -ComputerName $ProxyUrl.Host -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
    $statusCode = $null
    $remoteReachable = $false
    $errorMessage = $null

    if ($portReachable) {
        try {
            $response = Invoke-WebRequest -Uri 'https://api.openai.com/v1/models' -Proxy $ProxyUrl.AbsoluteUri -TimeoutSec 20 -SkipHttpErrorCheck
            $statusCode = [int]$response.StatusCode
            $remoteReachable = $statusCode -ge 200 -and $statusCode -lt 500
        }
        catch {
            $errorMessage = $_.Exception.Message
        }
    }

    [pscustomobject]@{
        action = 'Verify'
        proxyHost = $ProxyUrl.Host
        proxyPort = $port
        portReachable = [bool]$portReachable
        remoteReachable = $remoteReachable
        statusCode = $statusCode
        unauthenticatedButReachable = $statusCode -eq 401
        error = $errorMessage
    } | ConvertTo-Json -Depth 4
}

try {
    if (-not $IsWindows) {
        throw '此自动化脚本当前仅支持 Windows。'
    }

    switch ($Action) {
        'Detect' { Invoke-Detect }
        'Apply' { Invoke-Apply }
        'Verify' { Invoke-Verify }
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
