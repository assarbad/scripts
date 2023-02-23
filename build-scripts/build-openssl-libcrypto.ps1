#Requires -Version 6.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

###############################################################################################################################################################
##
## 2023, Oliver Schneider (assarbad.net)
##
## This helper script is placed into the public domain and alternatively licensed under CC0 in jurisdictions where public domain dedications have no effect.
##
## Disclaimer:
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
## FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
## WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##
###############################################################################################################################################################

## NB: the idea of this script is to build libcrypto static libs, it doesn't care about libssl currently.

$openssl = @{
    "1.1.1t" = "8dee9b24bdb1dcbf0c3d1e9b02fb8f6bf22165e807f45adeb7c9677536859d3b"
}
$nasm = @{
    "2.16.01" = "029eed31faf0d2c5f95783294432cbea6c15bf633430f254bb3c1f195c67ca3a"
}

<#
.Description
Downloads a file using Invoke-WebRequest. This is suboptimal, but should be okay for this sort of script.
#>
function Download_File
{
    Param (
        [Parameter(Mandatory=$true)]  [String]$url,
        [Parameter(Mandatory=$true)]  [String]$fname
    )

    $prevPreference = $global:ProgressPreference
    try
    {
        $global:ProgressPreference = 'SilentlyContinue'
        $tgtdir = [System.IO.Path]::GetDirectoryName($fname)
        if (-not (Test-Path -Path "$tgtdir" -PathType Container))
        {
            New-Item -Type Directory "$tgtdir"
        }
        Invoke-WebRequest $url -OutFile $fname -UseBasicParsing
    }
    finally 
    {
        $global:ProgressPreference = $prevPreference
    }
}

function Download_OpenSSL_version
{
    Param (
        [Parameter(Mandatory=$true)]  [String]$version,
        [Parameter(Mandatory=$true)]  [String]$knownhash,
        [Parameter(Mandatory=$true)]  [String]$tgtdir
    )

    $url = "https://www.openssl.org/source/openssl-${version}.tar.gz"
    $fname = $url.Substring($url.LastIndexOf("/") + 1)
    if (Test-Path -Path "$tgtdir\$fname" -PathType Leaf)
    {
        Write-Host -ForegroundColor yellow "Note: using existing file $tgtdir\$fname. If this is not desired, remove it prior to running this script."
    }
    else
    {
        $host.ui.WriteErrorLine("Downloading OpenSSL $version from $url as $fname (into $tgtdir)")
        Download_File $url "$tgtdir\$fname"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -Path "$tgtdir\$fname").Hash
    if ($knownhash -eq $hash)
    {
        Write-Host -ForegroundColor green "`tFile $fname downloaded and hash matches."
        [hashtable]$retval = @{ fpath="$tgtdir\$fname"; fname=$fname; version=$version; hash=$knownhash }
        return $retval
    }
    else
    {
        throw "The expected ($knownhash) and actual hashes ($hash) don't match for $fname!"
    }
}

function Download_NASM_version
{
    Param (
        [Parameter(Mandatory=$true)]  [String]$version,
        [Parameter(Mandatory=$true)]  [String]$knownhash,
        [Parameter(Mandatory=$true)]  [String]$tgtdir
    )

    $url = "https://www.nasm.us/pub/nasm/releasebuilds/$version/win64/nasm-${version}-win64.zip"
    $fname = $url.Substring($url.LastIndexOf("/") + 1)
    if (Test-Path -Path "$tgtdir\$fname" -PathType Leaf)
    {
        Write-Host -ForegroundColor yellow "Note: using existing file $tgtdir\$fname. If this is not desired, remove it prior to running this script."
    }
    else
    {
        $host.ui.WriteErrorLine("Downloading NASM $version from $url as $fname (into $tgtdir)")
        Download_File $url "$tgtdir\$fname"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -Path "$tgtdir\$fname").Hash
    if ($knownhash -eq $hash)
    {
        Write-Host -ForegroundColor green "`tFile $fname downloaded and hash matches."
        [hashtable]$retval = @{ fpath="$tgtdir\$fname"; fname=$fname; version=$version; hash=$knownhash }
        return $retval
    }
    else
    {
        throw "The expected ($knownhash) and actual hashes ($hash) don't match for $fname!"
    }
}

$funcs =
{
    <#
    .Description
    Checks the return code of the previous (native) command and throws an error with or without message, if the exit code was "unclean" (non-zero)
    #>
    function ThrowOnNativeFailure
    {
        Param($message)

        if (-not $?)
        {
            if ($message -ne $null)
            {
                $message = "Native failure: $message"
            }
            else
            {
                $message = "Unspecific native failure"
            }
            throw "$message"
        }
    }

    <#
    .Description
    This downloads the OpenSSL version defined in $openssl and checks the file hash against the known value and then unpacks the downloaded archive.
    #>
    function Import_OpenSSL
    {
        Param (
            [Parameter(Mandatory=$true)]  [hashtable]$details,
            [Parameter(Mandatory=$true)]  [String]$tgtdir
        )

        $version = $($details.version)
        $fname = $($details.fpath)
        $dirname = "$tgtdir\openssl-${version}"
        if (Test-Path -Path $dirname) # we want the folder freshly unpacked, always
        {
            $host.ui.WriteErrorLine("Removing existing folder $dirname")
            Remove-Item -Path $dirname -Recurse -Force
        }
        $host.ui.WriteErrorLine("Unpacking OpenSSL $version (hash matches)")
        # bsdtar is onboard in modern Windows versions
        tar -C "$tgtdir" -xf "$fname" | Out-Null
        ThrowOnNativeFailure "Failed to unpack $fname"
        if (!(Test-Path -Path $dirname))
        {
            throw "Expected to find a folder named '$dirname' after unpacking the archive."
        }
        return $dirname
    }

    <#
    .Description
    This downloads the NASM version defined in $nasm and checks the file hash against the known value and then unpacks the downloaded archive.
    #>
    function Import_NASM
    {
        Param (
            [Parameter(Mandatory=$true)]  [hashtable]$details,
            [Parameter(Mandatory=$true)]  [String]$tgtdir
        )

        $version = $($details.version)
        $fname = $($details.fpath)
        $dirname = "$tgtdir\nasm-${version}"
        if (Test-Path -Path $dirname) # we want the folder freshly unpacked, always
        {
            $host.ui.WriteErrorLine("Removing existing folder $dirname")
            Remove-Item -Path $dirname -Recurse -Force
        }
        $host.ui.WriteErrorLine("Unpacking NASM $version (hash matches)")
        Expand-Archive -Path $fname -DestinationPath $tgtdir -Force
        if (!(Test-Path -Path $dirname))
        {
            throw "Expected to find a folder named '$dirname' after unpacking the archive."
        }
        return $dirname
    }

    <#
    .Description
    This uses the known (and hardcoded) location of vswhere.exe to determine the latest Visual Studio, given the version range from $vsrange!
    #>
    function Get_VSBasePath
    {
        Param($vsrange = "[16.0,18.0)")

        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        $vspath = & $vswhere -products "*" -format value -property installationPath -latest -version "$vsrange"
        ThrowOnNativeFailure "Failed to retrieve path to Visual Studio installation (range: $vsrange)"
        return $vspath
    }

    function Copy_Finished
    {
        Param (
            [Parameter(Mandatory=$true)]  [String]$source,
            [Parameter(Mandatory=$true)]  [String]$target
        )
        Copy-Item -Force "$source" "$target"
        return $True
    }

    <#
    .Description
    Determines if sccache is available.
    #>
    function Get_sccache
    {
        return Get-Command sccache -CommandType Application -ErrorAction silentlycontinue
    }

    <#
    .Description
    Patches the OpenSSL makefile to get rid of some garbage, such as this perpetuated silliness of creating PDBs for static libs ...
    #>
    function Patch_Makefile
    {
        Param (
            [Parameter(Mandatory=$true)]  [String]$tgtdir
        )

        #$ccache = Get_sccache
        $cl = "cl"
        <#
        if ($ccache -ne $null)
        {
            $cl = "$ccache $cl"
        }
        #>
        # Patch the makefile so that the debug info is embedded in the object files (/Z7)
        echo "Patching makefile ..."
        Move-Item -Force .\makefile .\makefile.unpatched
        (Get-Content .\makefile.unpatched) `
            -replace '^(LIB_CFLAGS=)/Zi /Fdossl_static.pdb(.+)$', '$1/Brepro /Z7$2' `
            -replace '^(LDFLAGS=/nologo)( /debug)(.*)$', '$1$3 /Brepro' `
            -replace '^CC=cl$', "CC=$cl" `
            -replace '^(CFLAGS=/W3)', "`$1 /d1trimfile:'$tgtdir'" |
        Out-File .\makefile
    }

    <#
    .Description
    This builds libcrypto by invoking the correct commands in the correct order (as of OpenSSL 1.1.x)
    #>
    function Build_And_Place_LibCrypto
    {
        Param (
            [Parameter(Mandatory=$true)]  [hashtable]$nasm,
            [Parameter(Mandatory=$true)]  [hashtable]$ossl,
            [Parameter(Mandatory=$true)]  [String]$arch,
            [Parameter(Mandatory=$true)]  [String]$ossl_target,
            [Parameter(Mandatory=$true)]  [String]$target_fname,
            [Parameter(Mandatory=$true)]  [String]$ossl_hdrs,
            [Parameter(Mandatory=$true)]  [String]$staging
        )
        $tgtdir = "$staging\$ossl_target.$pid"
        try
        {
            $parentpath = "$pwd"
            Write-Host "Current job [$pid]: ${arch}: $ossl_target, $target_fname, $ossl_hdrs`n`$tgtdir = $tgtdir`n`$parentpath = $parentpath"

            if (-not (Test-Path -Path "$tgtdir" -PathType Container))
            {
                New-Item -Type Directory "$tgtdir"
            }

            $nasmdir = Import_NASM $nasm $tgtdir
            # Make our copy of NASM available
            $env:PATH =  $nasmdir + ";" + $env:PATH
            Write-Host -ForegroundColor white "NASM: $nasmdir"

            $vspath = Get_VSBasePath
            Import-Module "$vspath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll" -Force -cmdlet Enter-VsDevShell
            Enter-VsDevShell -VsInstallPath "$vspath" -DevCmdArguments "-arch=$arch -no_logo" -SkipAutomaticLocation
            $ossldir = Import_OpenSSL $ossl $tgtdir
            Write-Host -ForegroundColor white "OpenSSL dir: $ossldir"
            Push-Location -Path "$ossldir"

            # Probably a good idea also to add (needs to be validated!): no-autoalginit no-autoerrinit
            & perl Configure $ossl_target --api=1.1.0 --release threads no-shared no-filenames | Out-Host
            ThrowOnNativeFailure "Failed to configure OpenSSL for build ($ossl_target, $arch, $target_fname)"
            # Fix up the makefile to fit our needs better
            Patch_Makefile "$tgtdir"
            & nmake /nologo include\crypto\bn_conf.h include\crypto\dso_conf.h include\openssl\opensslconf.h libcrypto.lib *>&1
            # Copy-Item .\makefile "$parentpath\makefile.$pid"
            ThrowOnNativeFailure "Failed to build OpenSSL ($ossl_target, $arch, $target_fname)"
            $libpath = "$parentpath\lib"
            if (-not (Test-Path -Path "$libpath" -PathType Container))
            {
                New-Item -Type Directory "$libpath"
            }
            Copy_Finished .\libcrypto.lib "$libpath\$target_fname"
            if (Test-Path -Path "$parentpath\include\$ossl_hdrs" -PathType Container)
            {
                Remove-Item -Path "$parentpath\include\$ossl_hdrs" -Recurse -Force
            }
            Copy-Item -Recurse .\include\openssl "$parentpath\include\$ossl_hdrs"

            Pop-Location
        }
        finally
        {
            Write-Host -ForegroundColor yellow "Removing $tgtdir"
            Remove-Item -Path $tgtdir -Recurse -Force
        }
    }

    <#
    .Description
    Checks if Perl is available and if not found kicks off an _interactive_ installation of StrawberryPerl via winget (i.e. user can still choose to cancel).
    #>
    function Check_Perl_Available
    {
        $perl = Get-Command perl -CommandType Application -ErrorAction silentlycontinue
        if ($perl -eq $null)
        {
            echo "NOTE: You need to have Perl installed for this build for work. Kicking off the installation. Feel free to cancel, but be aware that the build will fail."
            winget install --accept-package-agreements --accept-source-agreements --exact --interactive --id StrawberryPerl.StrawberryPerl
            $perl = Get-Command perl -CommandType Application -ErrorAction silentlycontinue
            if ($perl -eq $null)
            {
                throw "Perl not available and wasn't installed by the user"
            }
        }
    }
} # $funcs

function Patch_opensslconf_Header
{
    Param (
        [Parameter(Mandatory=$true)]  [String]$srcfile,
        [Parameter(Mandatory=$true)]  [String]$tgtfile
    )

    $fname = Split-Path "$srcfile" -Leaf
    if ($fname -ne "opensslconf.h")
    {
        Write-Host -ForegroundColor Yellow "Not patching unexpected mismatched file $fname!"
        return
    }
    echo "Patching $fname ..."
    (Get-Content "$srcfile") `
        -replace '^#\s*?ifndef\s+?OPENSSL_SYS_WIN(32|64A)$', '#if defined(_M_AMD64)' `
        -replace '^(#(\s*?)define)\s+?OPENSSL_SYS_WIN(32|64A)\s+?\d+$', `
            "`$1 OPENSSL_SYS_WIN64A 1`n#elif defined(_M_IX86)`n`$1 OPENSSL_SYS_WIN32 1`n#else`n#`$2error This OpenSSL build is not prepared for the target platform!" `
        -replace '^#(\s+?)(define|undef)\s+(BN_LLONG)$', `
            "#if defined(_M_AMD64)`n#`${1}define `$3`n#elif defined(_M_IX86)`n#`${1}undef `$3`n#endif" `
        -replace '^#(\s*?)(define|undef)\s+?(SIXTY_FOUR_BIT)\s*?$', `
            "#if defined(_M_AMD64)`n`#`${1}define `$3`n#`${1}undef THIRTY_TWO_BIT`n#elif defined(_M_IX86)`n#`${1}undef `$3`n#`${1}define THIRTY_TWO_BIT`n#endif" `
        -replace '^#(\s*?)(define|undef)\s+?(THIRTY_TWO_BIT)\s*?$', '' |
    Out-File "$tgtfile"
}

function FinalizeHeaders
{
    Param (
        [Parameter(Mandatory=$true)]  [hashtable]$targets
    )
    $ossl_hdrs_common = "openssl"
    $ossl_target, $target_fname, $ossl_hdrs64 = $targets["x64"]
    $ossl_target, $target_fname, $ossl_hdrs = $targets["x86"]
    if (Test-Path -Path "$pwd\include\$ossl_hdrs" -PathType Container)
    {
        $incdir = "$pwd\include"
        Write-Host "Post-processing: $ossl_target, $target_fname, $ossl_hdrs"
        # Ensure the common include folder exists
        if (-not (Test-Path -Path "$incdir\$ossl_hdrs_common" -PathType Container))
        {
            New-Item -Type Directory "$incdir\$ossl_hdrs_common"|Out-Null
        }

        $hashes = Get-ChildItem -Path "$pwd\include\$ossl_hdrs" -File|%{ Get-FileHash $_ }|Select-Object -Property Hash,Path
        foreach($hash in $hashes)
        {
            $fname = Split-Path "$($hash.Path)" -Leaf
            if (Test-Path -Path "$pwd\include\$ossl_hdrs64\$fname" -PathType Leaf)
            {
                $otherhash = Get-FileHash "$pwd\include\$ossl_hdrs64\$fname"
                if ($($otherhash.Hash) -eq $($hash.Hash))
                {
                    Copy-Item -Force "$($hash.Path)" "$incdir\$ossl_hdrs_common\"
                }
                else
                {
                    Patch_opensslconf_Header "$($hash.Path)" "$incdir\$ossl_hdrs_common\$fname"
                }
            }
        }
    }
}

try
{
    $targets = @{ x86=@("VC-WIN32", "libcrypto32.lib", "openssl32"); x64=@("VC-WIN64A", "libcrypto64.lib", "openssl64") }
    $logpath = "$PSScriptRoot\build-openssl-libcrypto.log"
    $staging = "$pwd\staging"
    Start-Transcript -Path $logpath -Append

    $funcs:Check_Perl_Available
    
    # Cache copies of the files we need for the build
    foreach($version in $nasm.keys)
    {
        $nasm_details = Download_NASM_version "$version" "$($nasm.$version)" "$staging"
        break # use the first one always
    }
    foreach($version in $openssl.keys)
    {
        $ossl_details = Download_OpenSSL_version  "$version" "$($openssl.$version)" "$staging"
        break # use the first one always
    }
    foreach($tgt in $targets.GetEnumerator())
    {
        $arch = $($tgt.Name)
        $ossl_target, $target_fname, $ossl_hdrs = $($tgt.Value)
        Write-Host "Before starting job: ${arch}: $ossl_target, $target_fname, $ossl_hdrs"
        Start-Job -InitializationScript $funcs -Name "OpenSSL build: $($tgt.Name) ($ossl_target)" -ScriptBlock {Build_And_Place_LibCrypto $using:nasm_details $using:ossl_details $using:arch $using:ossl_target $using:target_fname $using:ossl_hdrs $using:staging}
    }

    while (Get-Job -State "Running")
    {
        Clear-Host
        Get-Job|%{ $runtime = "{0:hh}:{0:mm}:{0:ss}" -f ([datetime]::now - $_.PSBeginTime); Write-Host "$($_.Id): $($_.Name) -> $($_.State), $runtime" }
        Start-Sleep 2
    }

    FinalizeHeaders $targets
}
finally
{
    # Write output from the jobs (commented out, because we have a log file)
    Get-Job | Receive-Job
    Get-Job | %{ $duration = $_.PSEndTime - $_.PSBeginTime; Write-Host "$($_.Name) took $duration" }
    # Remove jobs from queue
    Get-Job | Remove-Job

    Stop-Transcript
}
