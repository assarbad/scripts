#Requires -Version 6.0
Set-StrictMode -Version Latest
Set-PSDebug -Off

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
    "WPDBusEnum"="Manual";
    "WSearch"="Automatic";
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
