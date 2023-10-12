<# ::
@echo off
:: Rename this file to .ps1.cmd to have this NT script wrapper take effect
set PSSCRIPT=%~dpnx0
set PSSCRIPT=%PSSCRIPT:.cmd=%
@echo on
copy /y "%~dpnx0" "%PSSCRIPT%" > nul
PowerShell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -File "%PSSCRIPT%" %*
set ERR=%ERRORLEVEL%
del /f "%PSSCRIPT%" > nul
@exit /b %ERR%
#>
#Requires -Version 6.0
Set-StrictMode -Version Latest
Set-PSDebug -Off
$VerbosePreference = "continue"

function ShowHeader()
{
    <#
    Reading actual Windows version from KUSER_SHARED_DATA
    xref: http://terminus.rewolf.pl/terminus/structures/ntdll/_KUSER_SHARED_DATA_combined.html
    xref: https://msrc-blog.microsoft.com/2022/04/05/randomizing-the-kuser_shared_data-structure-on-windows/
    #>
    $WinVerMaj = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x026c)
    $WinVerMin = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x0270)
    $WinVerBld = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x0260)
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    Write-Output "Windows: $WinVerMaj.$WinVerMin.$WinVerBld"
    Write-Output "Machine: $env:COMPUTERNAME (domain: $env:USERDOMAIN, logon server: $env:LOGONSERVER); admin: $IsAdmin`n"
}

$ServicesToRestore = @{
    "ssh-agent"="Disabled";
    "XboxGipSvc"="Manual";
    "XblAuthManager"="Manual";
    "XblGameSave"="Manual";
    "XboxNetApiSvc"="Manual";
    "bthserv"="Manual";
    "BTAGService"="Manual";
    "BthAvctpSvc"="Manual";
    "Wcmsvc"="Automatic";
    "WlanSvc"="Manual";
    "WwanSvc"="Manual";
    "TabletInputService"="Manual";
    "PhoneSvc"="Manual";
    "AxInstSV"="Manual";
    "AJRouter"="Manual";
    "autotimesvc"="Manual";
    "perceptionsimulation"="Manual";
    "spectrum"="Manual";
    "icssvc"="Manual";
    "MixedRealityOpenXRSvc"="Manual";
    "WMPNetworkSvc"="Manual";
    "MapsBroker"="Automatic";
    "lfsvc"="Manual";
    "lltdsvc"="Manual";
    "MSiSCSI"="Manual";
    "RemoteAccess"="Disabled";
    "RetailDemo"="Manual";
    "WinRM"="Manual";
    "SstpSvc"="Manual";
    "RasMan"="Manual";
    "RemoteRegistry"="Disabled";
    "PrintNotify"="Manual";
    "QWAVE"="Manual";
    "PeerDistSvc"="Manual";
    "wlidsvc"="Manual";
    "EntAppSvc"="Manual";
    "NgcSvc"="Manual";
    "NgcCtnrSvc"="Manual";
    "NcbService"="Manual";
    "SensorDataService"="Manual";
    "SensrSvc"="Manual";
    "SensorService"="Manual";
    "ScDeviceEnum"="Manual";
    "shpamsvc"="Disabled";
    "AppReadiness"="Manual";
    "ShellHWDetection"="Automatic";
    "SSDPSRV"="Manual";
    "WiaRpc"="Manual";
    "stisvc"="Manual";
    "wisvc"="Manual";
    "OneSyncSvc"="Automatic";
    "upnphost"="Manual";
    "UserDataSvc"="Manual";
    "UnistoreSvc"="Manual";
    "WalletService"="Manual";
    "WpnService"="Automatic";
    "dmwappushservice"="Manual";
    "RmSvc"="Manual";
    "WaaSMedicSvc"="Manual";
    "WPDBusEnum"="Manual";
    "WSearch"="Manual"; # don't really want this ... defaults to "Automatic", but we keep it at least on "Manual"
    "wuauserv"="Manual";
    # User services with wildcard and without
    "BluetoothUserService"="Manual";
    "PrintWorkflowUserSvc"="Manual";
    "BcastDVRUserService"="Manual";
    "CaptureService"="Manual";
    "CredentialEnrollmentManagerUserSvc"="Manual";
    "PimIndexMaintenanceSvc"="Manual";
    "CDPUserSvc"="Automatic";
    "cbdhsvc"="Manual";
    # ... wildcards ...
    "BluetoothUserService_*"="Manual";
    "PrintWorkflowUserSvc_*"="Manual";
    "BcastDVRUserService_*"="Manual";
    "CaptureService_*"="Manual";
    "CredentialEnrollmentManagerUserSvc_*"="Manual";
    "PimIndexMaintenanceSvc_*"="Manual";
    "CDPUserSvc_*"="Automatic";
    "cbdhsvc_*"="Manual"
}

function Restore-Service-StartType
{
    Param(
        [Parameter(Mandatory=$true)] $Service,
        [Parameter(Mandatory=$true)] [string]$startuptype,
        [Parameter(Mandatory=$true)] [string]$intstartuptype
    )

    Write-Host "Setting $($Service.Name) ($($Service.DisplayName)) to $startuptype [Current type/status: $($Service.StartType)/$($Service.Status)]"
    $Service|Set-Service -StartupType $startuptype -ErrorAction SilentlyContinue -ErrorVariable SvcCfgError
    if ($SvcCfgError)
    {
        Write-Host "`tTrying to forcibly set via registry ..."
        Set-Itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name" -Name Start -Value $intstartuptype -Type DWord -ErrorAction SilentlyContinue -ErrorVariable RegError
        if($RegError)
        {
            Write-Host "`tERROR: Unable to set startup type in registry."
            $RegError|Write-Verbose
        }
    }
}

function Restore-Services-StartType
{
    Param(
        [Parameter(Mandatory=$true)] [string]$name,
        [Parameter(Mandatory=$true)] [string]$value
    )

    $Services = Get-Service $name -ErrorAction SilentlyContinue -ErrorVariable SvcError
    if ($SvcError)
    {
        Write-Host "ERROR: Could not retrieve service '$name'."
        $SvcError|Write-Verbose
        return
    }
    foreach($svc in $Services)
    {
        $intvalue = [int]$($svc.StartType)
        Restore-Service-StartType $svc $value $intvalue
    }
}


$logpath = "$PSScriptRoot\windows-services-restore.log"
ShowHeader
try
{
    Start-Transcript -Path $logpath -Append

    foreach($entry in $ServicesToRestore.GetEnumerator())
    {
        Restore-Services-StartType $($entry.Name) $($entry.Value)
    }
}
finally
{
    Stop-Transcript
}
