[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot '../lib/CodexPerformance.Common.psm1') -Force

$controllers = Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, Status, PNPDeviceID
$displayDrivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceClass -eq 'DISPLAY' -or $_.DeviceName -match 'display|virtual|idd|oray'
} | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate, IsSigned

$virtual = @($displayDrivers | Where-Object { $_.DeviceName -match 'virtual|idd|oray' })
New-DiagnosticResult -Check 'display-drivers' -Status $(if ($virtual.Count) { 'warning' } else { 'ok' }) -Data @{
    video_controllers = @($controllers)
    display_drivers = @($displayDrivers)
    virtual_display_candidates = @($virtual)
} | Write-DiagnosticJson
