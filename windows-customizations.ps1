#Requires -Version 6.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'
Set-PSDebug -Off

<#
.Description
Self-elevates the current script.
NB: currently doesn't pass the script arguments on!
#>
function SelfElevateIfNeeded([string] $script)
{
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Host "UAC-elevating $script"
        # On Windows Vista and newer
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000)
        {
            $CommandLine = "-File `"$script`""
            $pwsh = (Get-Process -Id $PID).ProcessName + ".exe"
            Start-Process -FilePath $pwsh -Verb Runas -ArgumentList $CommandLine
            Exit # the unprivileged instance
        }
    }
}

<#
.Description
Writes pipe input in red (foreground) color, borrowed from https://stackoverflow.com/a/54778470
#>
function Red
{
    process { Write-Host $_ -ForegroundColor Red }
}

<#
.Description
Writes pipe input in green (foreground) color, borrowed from https://stackoverflow.com/a/54778470
#>
function Green
{
    process { Write-Host $_ -ForegroundColor Green }
}

<#
.Description
Writes pipe input in blue (foreground) color, borrowed from https://stackoverflow.com/a/54778470
#>
function Blue
{
    process { Write-Host $_ -ForegroundColor Blue }
}

<#
.Description
Writes pipe input in white (foreground) color, borrowed from https://stackoverflow.com/a/54778470
#>
function White
{
    process { Write-Host $_ -ForegroundColor White }
}

<#
.Description
Writes pipe input in yellow (foreground) color, borrowed from https://stackoverflow.com/a/54778470
#>
function Yellow
{
    process { Write-Host $_ -ForegroundColor Yellow }
}

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
    Write-Output "Windows: $WinVerMaj.$WinVerMin.$WinVerBld"|Green
    Write-Output "Machine: $env:COMPUTERNAME (domain: $env:USERDOMAIN, logon server: $env:LOGONSERVER)`n"|White
}

<#
.Description
This uses the known (and hardcoded) location of vswhere.exe to determine the latest Visual Studio, given the version range from $vsrange!
#>
function Get_VSBasePath
{
    Param($vsrange = "[16.0,18.0)")

    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -Path $vswhere -PathType Leaf)
    {
        $vspath = & $vswhere -products "*" -format value -property installationPath -latest -version "$vsrange"
        if ($?)
        {
            return $vspath
        }
    }
    return $null
}

function BroadcastEnvironmentChanged()
{
    if (-not ('Win32.NativeMethods' -as [type])) {
        # import SendMessageTimeout from Win32
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
            public static extern IntPtr SendMessageTimeout(
                IntPtr hWnd,
                uint Msg,
                UIntPtr wParam,
                string lParam,
                uint fuFlags,
                uint uTimeout,
                out UIntPtr lpdwResult
            );
'@
    }

    $HWND_BROADCAST = [System.IntPtr]0xFFFF
    $WM_SETTINGCHANGE = 0x001A

    $result = [System.UIntPtr]::Zero

    # Notify all windows of environment block change
    [Win32.NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [System.UIntPtr]::Zero,
        'Environment',
        2, # SMTO_ABORTIFHUNG
        2000,
        [ref]$result
    )
}

<#
function WaitForKey([string] $prompt = "Press a key to continue.")
{
    Write-Host $prompt
    [Console]::ReadKey() | Out-Null
}

function WinGetIsInstalled([Parameter(Mandatory=$true)] [string] $packageid)
{
    $installed = (winget.exe list --id $packageid --source winget -e |Select-String -Pattern "\W$packageid\W"|Measure-Object -Line).Lines
    return ($installed -gt 0)
}

function EchoCommand([string] $command)
{
    Write-Host $command
    Invoke-Expression $command
}

function WinGetInstall([Parameter(Mandatory=$true)] [string] $packageid, [Parameter(Mandatory=$false)] [string] $verb = "install")
{
    $winget = "&winget.exe $verb --exact --id `"$packageid`" --source winget --accept-package-agreements --accept-source-agreements"
    EchoCommand "$winget"
}

function WinGetInstallOrUpgrade([Parameter(Mandatory=$true)] [string] $packageid)
{
    if (-Not (WinGetIsInstalled "$packageid"))
    {
        WinGetInstall $packageid
    }
    else
    {
        Write-Host "`t... already installed, attempting upgrade"
        WinGetInstall $packageid "upgrade"
    }
}

function PrependEnvironmentVar([Parameter(Mandatory=$true)] [string] $name, [Parameter(Mandatory=$true)] [string] $toprepend, [string] $parent = "HKCU:\Environment")
{
    $envkey = Get-Item -Path $parent
    $oldvalue = $envkey.GetValue($name, $null, "DoNotExpandEnvironmentNames")
    Write-Host "[$name] old: $oldvalue"
    $newvalue = $toprepend
    if ($null -ne $oldvalue)
    {
        $newvalue = "$toprepend;$oldvalue"
    }
    Write-Host "[$name] new: $newvalue"
    Set-ItemProperty -Path $parent -Name $name -Value $newvalue -Type "ExpandString"
    BroadcastEnvironmentChanged
}
#>

<#
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Sysinternals\AccessChk]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\AccessEnum]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Active Directory Explorer]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ADInsight]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\AdRestore]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Autologon]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\AutoRuns]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\BGInfo]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\CacheSet]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ClockRes]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Contig]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Coreinfo]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\CPUSTRES]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Ctrl2cap]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\DbgView]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Desktops]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Disk2Vhd]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\DiskExt]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Diskmon]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\DiskView]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\EFSDump]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\FindLinks]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Handle]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Hex2Dec]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Junction]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\LdmDump]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ListDLLs]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\LiveKd]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\LoadOrder]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\LogonSessions]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Movefile]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\NotMyFault]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\NTFSInfo]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PageDefrag]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PendMove]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PipeList]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Portmon]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ProcDump]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Process Explorer]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Process Monitor]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsExec]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsFile]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsGetSid]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsInfo]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsKill]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsList]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsLoggedon]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsLoglist]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsPasswd]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsPing]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsService]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsShutdown]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\PsSuspend]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\RamMap]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\RegDelNull]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Regjump]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Regsize]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\SDelete]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Share Enum]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ShellRunas - Sysinternals: www.sysinternals.com]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\sigcheck]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Streams]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Strings]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Sync]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\TCPView]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\VMMap]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\VolumeID]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Whois]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\Winobj]
"EulaAccepted"=dword:00000001

[HKEY_CURRENT_USER\Software\Sysinternals\ZoomIt]
"EulaAccepted"=dword:00000001
#>
function SysinternalsEulaAccepted()
{
    $KeysToSet = (
        "AccessChk",
        "AccessEnum",
        "Active Directory Explorer",
        "ADInsight",
        "AdRestore",
        "Autologon",
        "AutoRuns",
        "BGInfo",
        "CacheSet",
        "ClockRes",
        "Contig",
        "Coreinfo",
        "CPUSTRES",
        "Ctrl2cap",
        "DbgView",
        "Desktops",
        "Disk2Vhd",
        "DiskExt",
        "Diskmon",
        "DiskView",
        "EFSDump",
        "FindLinks",
        "Handle",
        "Hex2Dec",
        "Junction",
        "LdmDump",
        "ListDLLs",
        "LiveKd",
        "LoadOrder",
        "LogonSessions",
        "Movefile",
        "NotMyFault",
        "NTFSInfo",
        "PageDefrag",
        "PendMove",
        "PipeList",
        "Portmon",
        "ProcDump",
        "Process Explorer",
        "Process Monitor",
        "PsExec",
        "PsFile",
        "PsGetSid",
        "PsInfo",
        "PsKill",
        "PsList",
        "PsLoggedon",
        "PsLoglist",
        "PsPasswd",
        "PsPing",
        "PsService",
        "PsShutdown",
        "PsSuspend",
        "RamMap",
        "RegDelNull",
        "Regjump",
        "Regsize",
        "SDelete",
        "Share Enum",
        "ShellRunas - Sysinternals: www.sysinternals.com",
        "sigcheck",
        "Streams",
        "Strings",
        "Sync",
        "TCPView",
        "VMMap",
        "VolumeID",
        "Whois",
        "Winobj",
        "ZoomIt"
    )
    foreach($key in $KeysToSet)
    {
        $subkey = "Software\Sysinternals\$key"
        if ( -not (Test-Path -Path HKCU:$subkey -PathType Container) )
        {
            New-Item -Path HKCU:$subkey|Out-Null
        }
        Set-ItemProperty -Path HKCU:$subkey -Type Dword -Name EulaAccepted -Value 1
    }
}

<#
; Approximates the following
[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation]
"RealTimeIsUniversal"=dword:00000001
#>
function SetRealTimeIsUTC()
{
    Set-ItemProperty HKLM:SYSTEM\CurrentControlSet\Control\TimeZoneInformation -Type Dword -Name RealTimeIsUniversal -Value 1
}

<#
; Approximates the following
[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad.exe]
@="C:\\Program Files\\Notepad++\\notepad++.exe"
#>
function SetNotepadPlusPlusIsNotepad()
{
    $npp = "${env:ProgramFiles}\Notepad++\notepad++.exe"
    if ( -not (Test-Path -Path $npp -PathType Leaf) )
    {
        Write-Debug "Not found in ${env:ProgramFiles}, trying ${env:ProgramFiles(x86)}"
        $npp = "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    }
    if (Test-Path -Path $npp -PathType Leaf)
    {
        $npp = $npp.replace(${env:ProgramFiles(x86)}, "%ProgramFiles(x86)%").replace(${env:ProgramFiles}, "%ProgramFiles%")
        Write-Host "`tUsing $npp (HKLM)"
        Set-Item -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad.exe" -Type ExpandString -Value $npp
    }
}

<#
; Approximates the following, but detecting the correct path
[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\guidgen.exe]
@="\"C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Enterprise\\Common7\\Tools\\guidgen.exe\""
#>
function SetGuidGen()
{
    $vspath = Get_VSBasePath
    if ($vspath -ne $null)
    {
        $guidgen = "$vspath\Common7\Tools\guidgen.exe"
        if (Test-Path -Path $guidgen -PathType Leaf)
        {
            $guidgen = $guidgen.replace(${env:ProgramFiles(x86)}, "%ProgramFiles(x86)%").replace(${env:ProgramFiles}, "%ProgramFiles%")
            Write-Host "`tUsing $guidgen (HKLM)"
            Set-Item -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\guidgen.exe" -Type ExpandString -Value $guidgen
        }
    }
}

<#
; Approximates the following, but for even more related programs
[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cl.exe\PerfOptions]
"CpuPriorityClass"=dword:00000005
"IoPriority"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\link.exe\PerfOptions]
"CpuPriorityClass"=dword:00000005
"IoPriority"=dword:00000001
#>
function SetLowerCompilerPrio()
{
    $vspath = Get_VSBasePath
    if ($vspath -ne $null)
    {
        $KeysToSet = (
            "bscmake.exe", # creation of browsing info
            "cl.exe", # compiler driver
            "link.exe", # linker
            "lib.exe", # librarian
            "ml.exe", # Macro Assembler
            "ml64.exe", # Macro Assembler (64 bit)
            "mspdbsrv.exe", # Creation of debug symbols
            "clang-cl.exe", # Clang compiler driver in "cl" mode
            "lld-link.exe", # LLVM linker in "link" mode
            "llvm-lib.exe" # LLVM librarian in "lib" mode
        )
        foreach($key in $KeysToSet)
        {
            $subkey = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$key\PerfOptions"
            if ( -not (Test-Path -Path HKLM:$subkey -PathType Container) )
            {
                New-Item -Path HKLM:$subkey -Force|Out-Null
            }
            # These are read by ntoskrnl!PspReadIFEOPerfOptions, via RtlQueryImageFileKeyOption
            # (also WorkingSetLimitInKB in addition to the below)
            #
            # CpuPriorityClass (PspSetProcessPriorityClass)
            # ----------------
            # 1 Idle
            # 2 Normal
            # 3 High
            # 4 Realtime (n/a)
            # 5 Below Normal
            # 6 Above Normal
            #
            # IoPriority
            # ----------------
            # 0 Very Low
            # 1 Low
            # 2 Normal
            # 3 High
            # 4 Critical
            #
            # PagePriority (MmGetDefaultPagePriority)
            # ------------
            # 0 Idle
            # 1 Very Low
            # 2 Low
            # 3 Background
            # 4 Background
            # 5 Normal
            $cpuprio = 5
            $ioprio = 1
            $pageprio = 2
            Set-ItemProperty -Path HKLM:$subkey -Type Dword -Name CpuPriorityClass -Value $cpuprio
            Set-ItemProperty -Path HKLM:$subkey -Type Dword -Name IoPriority -Value $ioprio
            # Set-ItemProperty -Path HKLM:$subkey -Type Dword -Name PagePriority -Value $pageprio
        }
    }
}

<#
[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem]
"LongPathsEnabled"=dword:00000001
"NTFSDisable8dot3NameCreation"=dword:00000001
"Win31FileSystem"=dword:00000000
"Win95TruncatedExtensions"=dword:00000000
#>
function EnableLongPathsDisable8dot3()
{
    $ValuesToSet = @{
        LongPathsEnabled=1;
        NTFSDisable8dot3NameCreation=1;
        Win31FileSystem=0;
        Win95TruncatedExtensions=0
    }
    foreach($val in $ValuesToSet.GetEnumerator())
    {
        $valname = $($val.Name)
        $value = $($val.Value)
        Set-ItemProperty -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Type Dword -Name $valname -Value $value
    }
}

function TelemetryOptOutAndMore()
{
    $EnvVarsoSet = @{
        VCPKG_DISABLE_METRICS="1";
        VCPKG_KEEP_ENV_VARS="VSCMD_SKIP_SENDTELEMETRY";
        VSCMD_SKIP_SENDTELEMETRY="1"
        DOTNET_NOLOGO="true";
        DOTNET_CLI_TELEMETRY_OPTOUT="1";
        POWERSHELL_TELEMETRY_OPTOUT="1";
        POWERSHELL_UPDATECHECK="Off";
        DO_NOT_TRACK="1"
    }
    foreach($val in $EnvVarsoSet.GetEnumerator())
    {
        $valname = $($val.Name)
        $value = $($val.Value)
        [Environment]::SetEnvironmentVariable($valname, $value, 'Machine')
    }
    BroadcastEnvironmentChanged|Out-Null
}

function DisableFireFoxTelemetry()
{
    $KeysToSet = (
        "HKLM:Software\Policies\Mozilla\Firefox",
        "HKCU:Software\Policies\Mozilla\Firefox"
    )
    foreach($key in $KeysToSet)
    {
        if ( -not (Test-Path -Path $key -PathType Container) )
        {
            New-Item -Path $key -Force|Out-Null
        }
        Set-ItemProperty -Path $key -Type Dword -Name DisableTelemetry -Value 1
    }
}

<#
[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Debug Print Filter]
"DEFAULT"=dword:ffffffff
#>
function SetDefaultDebugFilter()
{
    $key = "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Debug Print Filter"
    if ( -not (Test-Path -Path $key -PathType Container) )
    {
        New-Item -Path $key -Force|Out-Null
    }
    Set-ItemProperty -Path $key -Type Dword -Name DEFAULT -Value 0xffffffff
}

<#
[HKEY_CLASSES_ROOT\Directory\shell\git_shell\command]
; REG_EXPAND_SZ
; -> "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -w 0 -p "Git Bash" -d "%V"
@=hex(2):22,00,25,00,4c,00,4f,00,43,00,41,00,4c,00,41,00,50,00,50,\
  00,44,00,41,00,54,00,41,00,25,00,5c,00,4d,00,69,00,63,00,72,00,6f,00,73,00,\
  6f,00,66,00,74,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,41,00,70,\
  00,70,00,73,00,5c,00,77,00,74,00,2e,00,65,00,78,00,65,00,22,00,20,00,2d,00,\
  77,00,20,00,30,00,20,00,2d,00,70,00,20,00,22,00,47,00,69,00,74,00,20,00,42,\
  00,61,00,73,00,68,00,22,00,20,00,2d,00,64,00,20,00,22,00,25,00,56,00,22,00,\
  00,00

[HKEY_CLASSES_ROOT\Directory\Background\shell\git_shell\command]
; REG_EXPAND_SZ
; -> "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -w 0 -p "Git Bash" -d "%V"
@=hex(2):22,00,25,00,4c,00,4f,00,43,00,41,00,4c,00,41,00,50,00,50,\
  00,44,00,41,00,54,00,41,00,25,00,5c,00,4d,00,69,00,63,00,72,00,6f,00,73,00,\
  6f,00,66,00,74,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,41,00,70,\
  00,70,00,73,00,5c,00,77,00,74,00,2e,00,65,00,78,00,65,00,22,00,20,00,2d,00,\
  77,00,20,00,30,00,20,00,2d,00,70,00,20,00,22,00,47,00,69,00,74,00,20,00,42,\
  00,61,00,73,00,68,00,22,00,20,00,2d,00,64,00,20,00,22,00,25,00,56,00,22,00,\
  00,00

[HKEY_CLASSES_ROOT\LibraryFolder\background\shell\git_shell\command]
; REG_EXPAND_SZ
; -> "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -w 0 -p "Git Bash" -d "%V"
@=hex(2):22,00,25,00,4c,00,4f,00,43,00,41,00,4c,00,41,00,50,00,50,\
  00,44,00,41,00,54,00,41,00,25,00,5c,00,4d,00,69,00,63,00,72,00,6f,00,73,00,\
  6f,00,66,00,74,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,41,00,70,\
  00,70,00,73,00,5c,00,77,00,74,00,2e,00,65,00,78,00,65,00,22,00,20,00,2d,00,\
  77,00,20,00,30,00,20,00,2d,00,70,00,20,00,22,00,47,00,69,00,74,00,20,00,42,\
  00,61,00,73,00,68,00,22,00,20,00,2d,00,64,00,20,00,22,00,25,00,56,00,22,00,\
  00,00

; HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\background\shell\git_shell
#>
function EnableGitBashHereInWindowsTerminal()
{
    # Detect presence of wt.exe App Execution Alias and/or App Paths entry
    if ( `
        (Test-Path -Path "HKCU:Software\Microsoft\Windows\CurrentVersion\App Paths\wt.exe" -PathType Container) `
        -or `
        (Test-Path -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wt.exe" -PathType Container) `
        )
    {
        if (Test-Path -Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe" -PathType Leaf)
        {
            $value = "`"%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe`" -w 0 -p `"Git Bash`" -d `"%V`""
            $KeysToCheckAndSet = (
                "Registry::HKCR\Directory\shell\git_shell\command",
                "Registry::HKCR\Directory\Background\shell\git_shell\command",
                "Registry::HKCR\LibraryFolder\background\shell\git_shell\command"
            )
            foreach($key in $KeysToCheckAndSet)
            {
                if (Test-Path -Path $key -PathType Container)
                {
                    Set-ItemProperty -Path $key -Type ExpandString -Name '(Default)' -Value $value -Force
                    Write-Host -NoNewline "`tInfo: "|White
                    Write-Host "$key"
                    Write-Host "`t-> $value"
                }
                else
                {
                    Write-Host -NoNewline "`tWarning: "|Yellow
                    Write-Host -NoNewline "'$key'"|White
                    Write-Host "not found. Ignoring."
                }
            }
        }
    }
}

function main()
{
    ShowHeader

    Write-Host "Setting EulaAccepted for Sysinternals tools"
    SysinternalsEulaAccepted
    Write-Host "Setting that RTC is kept in UTC"
    SetRealTimeIsUTC
    Write-Host "Making Notepad++ available via App Paths (notepad.exe)"
    SetNotepadPlusPlusIsNotepad
    Write-Host "Making guidgen.exe available via App Paths"
    SetGuidGen
    Write-Host "Setting lower compiler/linker/librarian priority if VS detected"
    SetLowerCompilerPrio
    Write-Host "Disabling 8.3 names and enabling long paths (requires reboot!)"
    EnableLongPathsDisable8dot3
    Write-Host "Opting out from telemetry in various programs via environment variables"
    TelemetryOptOutAndMore
    Write-Host "Disabling Firefox telemetry"
    DisableFireFoxTelemetry
    Write-Host "Setting DEFAULT Debug Filter"
    SetDefaultDebugFilter
    Write-Host "Enabling Git Bash for Windows Terminal"
    EnableGitBashHereInWindowsTerminal
}

SelfElevateIfNeeded $MyInvocation.MyCommand.Path
main
