#Requires -Version 6.0
Set-StrictMode -Version Latest
Set-PSDebug -Off

function Configure-And-Set-Service
{
    Param(
        [Parameter(Mandatory=$true)] [string]$name,
        [Parameter(Mandatory=$true)] [string]$state,
        [Parameter(Mandatory=$false)] [bool]$start = $false,
        [Parameter(Mandatory=$false)] [bool]$stop = $false
    )

    $Service = Get-Service -Name $name -ErrorAction SilentlyContinue -ErrorVariable SvcError
    if ($SvcError)
    {
        Write-Host "ERROR: Could not retrieve service '$name'."
        $SvcError|Write-Verbose
        return
    }
    Write-Host "Setting $($Service.Name) ($($Service.DisplayName)) to $state [Current type/status: $($Service.StartType)/$($Service.Status)]"
    $Service|Set-Service -StartupType $state -ErrorAction SilentlyContinue -ErrorVariable SvcCfgError
    if ($SvcCfgError -and ($state -eq "Disabled") -and ($($Service.StartType) -ne $state))
    {
        Write-Host "`tTrying to forcibly disable via registry ..."
        Set-Itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name" -Name Start -Value 4 -Type DWord
    }
    if ($stop -and $start)
    {
        $Service|Restart-Service -Force
        return
    }
    if ($stop -and ($($Service.Status) -ne "Stopped"))
    {
        $Service|Stop-Service -Force
        return
    }
    if ($start -and ($($Service.Status) -ne "Running"))
    {
        $Service|Start-Service
        return
    }
}

function Stop-And-Disable-Service
{
    Param(
        [Parameter(Mandatory=$true)] [string]$name
    )

    Configure-And-Set-Service $name Disabled $false $true
}

# Also see: https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/WindowsServerDocs/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server.md

$ServicesToStopAndDisable = (
    # HP-related bloatware
    "HotKeyServiceDSU", # HP DSU Service
    "HPDiagsCap", # HP Diagnostics HSA Service
    "HPNetworkCap", # HP Network HSA Service
    "HPSysInfoCap", # HP System Info HSA Service
    "HPAppHelperCap", # HP App Helper HSA Service
    "HpTouchpointAnalyticsService", # HP Analytics service
    "LanWlanWwanSwitchingServiceDSU", # HP DSU LAN/WLAN/WWAN Switching Service
    # Using PuTTY with Pageant, so get rid of the following one
    "ssh-agent", # OpenSSH Authentication Agent
    # Xbox-related
    "XboxGipSvc", # Xbox Accessory Management Service
    "XblAuthManager", # Xbox Live Auth Manager
    "XblGameSave", # Xbox Live Game Save
    "XboxNetApiSvc", # Xbox Live Networking Service
    # Bluetooth-related
    "bthserv", # Bluetooth Support Service
    "BTAGService", # Bluetooth Audio Gateway Service
    "BthAvctpSvc", # AVCTP service
    # Office
    "ose64", # Office 64 Source Engine
    "OfficeSvcManagerAddons", # OfficeSvcManagerAddons
    # Logitech bloatware
    "nebula", # Logitech Video Camera Service
    # Intel bloatware
    "LMS", # Intel(R) Management and Security Application Local Management Service
    "XTU3SERVICE", # XTUOCDriverService
    # Default Windows services I do not need
    "Wcmsvc", # Windows Connection Manager
    "WlanSvc", # WLAN AutoConfig
    "WwanSvc", # WWAN AutoConfig
    "IpOverUsbSvc", # Windows Phone IP over USB Transport (IpOverUsbSvc)
    "TabletInputService", # Touch Keyboard and Handwriting Panel Service
    ## NB: The above is required by Windows Terminal, unless the following gets set:
    ## [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Input]
    ## "InputServiceEnabled"=dword:00000000
    ## "InputServiceEnabledForCCI"=dword:00000001
    ## ... but even then the Find popup window won't take the Enter key
    ## xref: https://github.com/microsoft/terminal/issues/4448#issuecomment-617290424
    "PhoneSvc", # Phone Service
    "AxInstSV", # ActiveX Installer (AxInstSV)
    "AJRouter", # AllJoyn Router Service
    "autotimesvc", # Cellular Time
    "perceptionsimulation", # Windows Perception Simulation Service
    "spectrum", # Windows Perception Service
    "icssvc", # Windows Mobile Hotspot Service (formerly Internet Connection Sharing)
    "MixedRealityOpenXRSvc", # Windows Mixed Reality OpenXR Service
    "WMPNetworkSvc", # WMPNetworkSvc
    "MapsBroker", # MapsBroker
    "SECOMNService", # Sound Research SECOMN Service
    "lfsvc", # Geolocation Service
    "lltdsvc", # Link-Layer Topology Discovery Mapper
    "MSiSCSI", # Microsoft iSCSI Initiator Service
    # "cloudidsvc", unsure about this one as of yet
    "RemoteAccess", # Routing and Remote Access
    "RetailDemo", # Retail Demo Service
    "WinRM", # Windows Remote Management (WS-Management)
    "SstpSvc", # Secure Socket Tunneling Protocol Service
    "RasMan", # Remote Access Connection Manager
    "RemoteRegistry", # Remote Registry
    "PrintNotify", # Printer Extensions and Notifications
    "QWAVE", # Quality Windows Audio Video Experience
    "PeerDistSvc", # BranchCache
    "wlidsvc", # Microsoft Account Sign-in Assistant
    "EntAppSvc", # Enterprise App Management Service
    "NgcSvc", # Microsoft Passport
    "NgcCtnrSvc", # Microsoft Passport Container
    "NcbService", # Network Connection Broker
    "SensorDataService", # Sensor Data Service
    "SensrSvc", # Sensor Monitoring Service
    "SensorService", # Sensor Service
    "ScDeviceEnum", # Smart Card Device Enumeration Service (Needed almost exclusively for WinRT apps)
    "shpamsvc", # Shared PC Account Manager
    "AppReadiness", # App Readiness
    "ShellHWDetection", # Shell Hardware Detection
    "SSDPSRV", # SSDP Discovery
    "WiaRpc", # Still Image Acquisition Events
    "stisvc", # Windows Image Acquisition (WIA)
    "wisvc", # Windows Insider Service
    "OneSyncSvc", # Sync Host
    "upnphost", # UPnP Device Host
    "UserDataSvc", # User Data Access
    "UnistoreSvc", # User Data Storage
    "WalletService", # WalletService
    "WpnService", # Windows Push Notifications System Service
    "dmwappushservice", # Device Management Wireless Application Protocol (WAP) Push message Routing Service
    "RmSvc", # Radio Management Service
    "WPDBusEnum", # Portable Device Enumerator Service (arguably for MTP devices etc)
    "WSearch" # Windows Search
)

$ServicesToStopAndDisableByWildCard = (
    "BluetoothUserService_*",
    "BluetoothUserService",
    "PrintWorkflowUserSvc_*",
    "PrintWorkflowUserSvc",
    "BcastDVRUserService_*",
    "BcastDVRUserService",
    "CaptureService_*",
    "CaptureService",
    "CredentialEnrollmentManagerUserSvc_*",
    "CredentialEnrollmentManagerUserSvc",
    "PimIndexMaintenanceSvc_*",
    "PimIndexMaintenanceSvc",
    "CDPUserSvc_*",
    "CDPUserSvc",
    "cbdhsvc_*",
    "cbdhsvc"
)

$logpath = "$PSScriptRoot\windows-services.log"

try
{
    Start-Transcript -Path $logpath -Append

    Configure-And-Set-Service "SuRunSVC" Automatic $true $false
    Configure-And-Set-Service "TeamViewer" Manual $false $true

    foreach($svcname in $ServicesToStopAndDisable)
    {
        Stop-And-Disable-Service "$svcname"
    }

    foreach($svcname in $ServicesToStopAndDisableByWildCard)
    {
        Get-Service "$svcname" -ErrorAction SilentlyContinue -ErrorVariable SvcError|%{ Stop-And-Disable-Service $_.Name }
    }

    $Service = Get-Service -Name "TabletInputService" -ErrorAction SilentlyContinue -ErrorVariable SvcError
    if (!$SvcError)
    {
        if (($Service.StartType -eq "Manual") -or ($Service.StartType -eq "Disabled"))
        {
            Write-Host "Setting InputServiceEnabled=0"
            Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Input" -Name "InputServiceEnabled" -Value 0 -Type DWord
        }
    }
}
finally
{
    Stop-Transcript
}
