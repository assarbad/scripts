#Requires -Version 6.0
[CmdletBinding()]
param(
    [switch]$LibSsl = $false,
    [switch]$NoDebugInfo = $false,
    [switch]$NoDeleteBuildDirectories = $false,
    [switch]$UseMasm = $false,
    [switch]$UseSccache = $false
)
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

$openssl = @{
    "1.1.1w" = "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8"
}
# $openssl30x = @{
#     "3.0.11" = "b3425d3bb4a2218d0697eb41f7fc0cdede016ed19ca49d168b78e8d947887f55"
# }
# $openssl31x = @{
#     "3.1.3" = "f0316a2ebd89e7f2352976445458689f80302093788c466692fb2a188b2eacf6"
# }
$nasm = @{
    "2.16.01" = "029eed31faf0d2c5f95783294432cbea6c15bf633430f254bb3c1f195c67ca3a"
}

<#
.Description
Downloads a file using Invoke-WebRequest. This is suboptimal, but should be okay for this sort of script.
#>
function Download_File
{
    param(
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
            New-Item -Type Directory "$tgtdir" | Out-Null
        }
        Invoke-WebRequest $url -OutFile $fname -UseBasicParsing
    }
    finally 
    {
        $global:ProgressPreference = $prevPreference
    }
}

<#
.Description
Downloads the given version of the OpenSSL tarball, checks the hash and returns a boolean denoting success or failure
#>
function Download_OpenSSL_version
{
    param(
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

<#
.Description
Downloads the given version of the NASM x64 ZIP file, checks the hash and returns a boolean denoting success or failure
#>
function Download_NASM_version
{
    param(
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
        param($message)

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
        param(
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
        param(
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
        param($vsrange = "[16.0,18.0)")

        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        $vspath = & $vswhere -products "*" -format value -property installationPath -latest -version "$vsrange"
        ThrowOnNativeFailure "Failed to retrieve path to Visual Studio installation (range: $vsrange)"
        return $vspath
    }

    function Copy_Finished
    {
        param(
            [Parameter(Mandatory=$true)]  [String]$source,
            [Parameter(Mandatory=$true)]  [String]$target
        )
        Copy-Item -Force "$source" "$target"
        return $True
    }

    <#
    .Description
    Patches the OpenSSL makefile to get rid of some garbage, such as this perpetuated silliness of creating PDBs for static libs ...
    #>
    function Patch_Makefile
    {
        $cl = "cl"
        # Patch the makefile so that the debug info is embedded in the object files (/Z7)
        echo "Patching makefile ..."
        Move-Item -Force .\makefile .\makefile.unpatched
        (Get-Content .\makefile.unpatched) `
            -replace '/Zi /Fdossl_static.pdb', "" |
        Out-File .\makefile
    }

    <#
    .Description
    Uses a suffix to create a lib name that contains the suffix. Example (suffix="32") "libcrypto.lib" -> "libcrypto32.lib"
    #>
    function FileNameFromTargetName
    {
        param(
            [Parameter(Mandatory=$true)]  [String]$path,
            [Parameter(Mandatory=$true)]  [String]$suffix
        )
        $basename = Split-Path $path -LeafBase
        $ext = Split-Path $path -Extension
        return "$basename$suffix$ext"
    }

    <#
    .Description
    This builds libcrypto by invoking the correct commands in the correct order (as of OpenSSL 1.1.x)
    #>
    function BuildAndPlaceOpenSSLLib
    {
        param(
            [Parameter(Mandatory=$true)]  [hashtable]$nasm,
            [Parameter(Mandatory=$true)]  [hashtable]$ossl,
            [Parameter(Mandatory=$true)]  [String]$arch,
            [Parameter(Mandatory=$true)]  [String]$ossl_target,
            [Parameter(Mandatory=$true)]  [String]$tgt_base_suffix,
            [Parameter(Mandatory=$true)]  [String]$ossl_hdrs,
            [Parameter(Mandatory=$true)]  [String]$staging
        )
        $blddir = "$staging\$ossl_target.$pid"
        try
        {
            $parentpath = "$pwd"
            $hdrsubdir = "$ossl_hdrs$tgt_base_suffix"
            $tgtincdir = "$parentpath\include\$hdrsubdir"
            Write-Host "Current job [$pid]: ${arch}: $ossl_target, $hdrsubdir`n`$blddir = $blddir`n`$parentpath = $parentpath"

            if (-not (Test-Path -Path "$blddir" -PathType Container))
            {
                New-Item -Type Directory "$blddir" | Out-Null
            }

            if ($global:UseMasm)
            {
                $configure_ossl_target = "${ossl_target}-masm"
                Write-Host -ForegroundColor white "Using MASM"
            }
            else
            {
                $configure_ossl_target = $ossl_target
                $nasmdir = Import_NASM $nasm $blddir
                # Make our copy of NASM available
                $env:PATH =  $nasmdir + ";" + $env:PATH
                Write-Host -ForegroundColor white "NASM: $nasmdir"
            }

            $vspath = Get_VSBasePath
            Import-Module "$vspath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll" -Force -cmdlet Enter-VsDevShell
            Enter-VsDevShell -VsInstallPath "$vspath" -DevCmdArguments "-arch=$arch -no_logo" -SkipAutomaticLocation
            $ossldir = Import_OpenSSL $ossl $blddir
            Write-Host -ForegroundColor white "OpenSSL dir: $ossldir"
            Push-Location -Path "$ossldir"

            $target_fname = FileNameFromTargetName "libcrypto.lib" $tgt_base_suffix
            Write-Host "Target file name for lib: $target_fname"

            $env:LOG_BUILD_COMMANDLINES="$blddir\buildcmdlines.log"
            $srcepoch = ([DateTimeOffset](Get-Item "$pwd\INSTALL").LastWriteTime).ToUnixTimeSeconds() # any freshly unpacked file will do
            $env:SOURCE_DATE_EPOCH="$srcepoch"

            # Probably a good idea also to add (needs to be validated!): no-autoalginit no-autoerrinit
            & perl Configure $configure_ossl_target --api=1.1.0 --release threads no-shared no-filenames | Out-Host
            ThrowOnNativeFailure "Failed to configure OpenSSL for build ($configure_ossl_target, $arch, $target_fname)"
            Write-Host -ForegroundColor white "${arch}: libssl = $global:LibSsl, no debug info = $global:NoDebugInfo, don't delete build directories = $global:NoDeleteBuildDirectories, use sccache = $global:UseSccache"
            if (Test-Path -Path "$staging\bin\cl.exe" -PathType Leaf)
            {
                $env:SCCACHE_ERROR_LOG="$staging\sccache_err.log"
                $env:SCCACHE_LOG="debug"
                if (Test-Path -Path "$staging\sccache" -PathType Container)
                {
                    $env:SCCACHE_DIR="$staging\sccache"
                }
                $env:PATH="$staging\bin;$env:PATH"
            }
            $env:CL="/nologo"
            $env:LIB="/nologo"
            $env:LINK="/nologo"
            $env:ML="/nologo"
            # A non-invasive way of getting /Brepro into the build
            $env:_LIB_="/Brepro"
            $env:_LINK_="/Brepro"
            # Fix up the makefile to fit our needs better
            if ($global:NoDebugInfo)
            {
                Patch_Makefile
                $env:_CL_="/d1trimfile:'$blddir' /Brepro"
                $env:_ML_="/Brepro"
            }
            else
            {
                Patch_Makefile
                $env:_CL_="/d1trimfile:'$blddir' /Brepro /Z7"
                $env:_ML_="/Brepro /Zi"
            }
            if ($global:LibSsl)
            {
                & nmake /nologo build_generated libcrypto.lib libssl.lib *>&1
            }
            else
            {
                & nmake /nologo build_generated libcrypto.lib *>&1
            }
            Copy-Item .\makefile "$parentpath\makefile.$pid"
            ThrowOnNativeFailure "Failed to build OpenSSL ($ossl_target, $arch, $target_fname)"
            $libpath = "$parentpath\lib"
            if (-not (Test-Path -Path "$libpath" -PathType Container))
            {
                New-Item -Type Directory "$libpath" | Out-Null
            }
            Copy_Finished .\libcrypto.lib "$libpath\$target_fname"
            if ($global:LibSsl)
            {
                $target_fname2 = FileNameFromTargetName "libssl.lib" $tgt_base_suffix
                Copy_Finished .\libssl.lib "$libpath\$target_fname2"
            }
            if (Test-Path -Path "$tgtincdir" -PathType Container)
            {
                Write-Host -ForegroundColor yellow "Removing target include directory $tgtincdir"
                Remove-Item -Path "$tgtincdir" -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -Recurse .\include\openssl "$tgtincdir"

            Pop-Location
        }
        finally
        {
            Write-Host -ForegroundColor white "${arch}: libssl = $global:LibSsl, no debug info = $global:NoDebugInfo, don't delete build directories = $global:NoDeleteBuildDirectories, use sccache = $global:UseSccache"
            if ($global:NoDeleteBuildDirectories)
            {
                Write-Host -ForegroundColor green "Keeping build directory $blddir ($global:NoDeleteBuildDirectories)"
            }
            else
            {
                Write-Host -ForegroundColor yellow "Removing build directory $blddir ($global:NoDeleteBuildDirectories)"
            }
        }
    }

    <#
    .Description
    Checks if Perl is available and if not found kicks off an _interactive_ installation of StrawberryPerl via winget (i.e. user can still choose to cancel).
    #>
    function Check_Perl_Available
    {
        $perl = Get-Command perl -CommandType Application -ErrorAction SilentlyContinue
        if ($perl -eq $null)
        {
            echo "NOTE: You need to have Perl installed for this build for work. Kicking off the installation. Feel free to cancel, but be aware that the build will fail."
            winget install --accept-package-agreements --accept-source-agreements --exact --interactive --id StrawberryPerl.StrawberryPerl
            $perl = Get-Command perl -CommandType Application -ErrorAction SilentlyContinue
            if ($perl -eq $null)
            {
                throw "Perl not available and wasn't installed by the user"
            }
        }
    }
} # $funcs

<#
.Description
Patches the openssl/opensslconf.h to unify the x86 and x64 headers generated during the OpenSSL builds.
#>
function Patch_opensslconf_Header
{
    param(
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
            "`$1 OPENSSL_SYS_WIN64A 1`r`n#elif defined(_M_IX86)`r`n`$1 OPENSSL_SYS_WIN32 1`r`n#else`r`n#`$2error This OpenSSL build is not prepared for the target platform!" `
        -replace '^#(\s+?)(define|undef)\s+(BN_LLONG)$', `
            "#if defined(_M_AMD64)`r`n#`${1}define `$3`r`n#elif defined(_M_IX86)`r`n#`${1}undef `$3`r`n#endif" `
        -replace '^#(\s*?)(define|undef)\s+?(SIXTY_FOUR_BIT)\s*?$', `
            "#if defined(_M_AMD64)`r`n`#`${1}define `$3`r`n#`${1}undef THIRTY_TWO_BIT`r`n#elif defined(_M_IX86)`r`n#`${1}undef `$3`r`n#`${1}define THIRTY_TWO_BIT`r`n#endif" `
        -replace '^#(\s*?)(define|undef)\s+?(THIRTY_TWO_BIT)\s*?$', '' |
    Out-File "$tgtfile"
}

<#
.Description
Verifies that all generated header files except for opensslconf.h are identical, copies the identical ones
into a common include/openssl folder and patches the opensslconf.h to make it available for both x86 and x64
on Windows.
#>
function FinalizeHeaders
{
    param(
        [Parameter(Mandatory=$true)]  [hashtable]$targets
    )

    $ossl_hdrs_common = "openssl"
    $ossl_target, $tgt_base_suffix64, $null = $targets["x64"]
    $ossl_target, $tgt_base_suffix32, $null = $targets["x86"]
    $incdir = "$pwd\include\$ossl_hdrs_common"
    $incdir32 = "$incdir$tgt_base_suffix32"
    $incdir64 = "$incdir$tgt_base_suffix64"
    if (Test-Path -Path "$incdir32" -PathType Container)
    {
        Write-Host "Post-processing: $ossl_target, $incdir32 -> $incdir"
        # Ensure the common include folder exists
        if (-not (Test-Path -Path "$incdir" -PathType Container))
        {
            New-Item -Type Directory "$incdir" | Out-Null
        }

        $hashes = Get-ChildItem -Path "$incdir32" -File|%{ Get-FileHash $_ }|Select-Object -Property Hash,Path
        foreach($hash in $hashes)
        {
            $fname = Split-Path "$($hash.Path)" -Leaf
            if (Test-Path -Path "$incdir64\$fname" -PathType Leaf)
            {
                $otherhash = Get-FileHash "$incdir64\$fname"
                if ($($otherhash.Hash) -eq $($hash.Hash))
                {
                    Copy-Item -Force "$($hash.Path)" "$incdir"
                }
                else
                {
                    Patch_opensslconf_Header "$($hash.Path)" "$incdir\$fname"
                }
            }
        }
    }
}

try
{
    $targets = @{ x86=@("VC-WIN32", "32"); x64=@("VC-WIN64A", "64") }
    $logpath = "$PSScriptRoot\build-openssl-libcrypto.log"
    $staging = "$pwd\staging"
    Start-Transcript -Path $logpath -Append

    $funcs:Check_Perl_Available
    
    # Cache copies of the files we need for the build
    if ($UseMasm)
    {
        $nasm_details = @{ }
    }
    else
    {
        foreach($version in $nasm.keys)
        {
            $nasm_details = Download_NASM_version "$version" "$($nasm.$version)" "$staging"
            break # use the first one always
        }
    }
    foreach($version in $openssl.keys)
    {
        $ossl_details = Download_OpenSSL_version  "$version" "$($openssl.$version)" "$staging"
        break # use the first one always
    }

    Write-Host -ForegroundColor white "Going to build: libssl = $LibSsl, no debug info = $NoDebugInfo, don't delete build directories = $NoDeleteBuildDirectories, use sccache = $UseSccache"

    if ($UseSccache)
    {
        $ccache = Get-Command sccache -CommandType Application -ErrorAction SilentlyContinue
        if ($ccache -ne $null)
        {
            $ccache = $ccache.Path
            Write-Host -ForegroundColor white "Using sccache: $ccache"
            $fakebindir = "$staging\bin"
            New-Item -Type Directory $fakebindir -ErrorAction SilentlyContinue | Out-Null
            Copy-Item -Force "$ccache" "$fakebindir\cl.exe"
            New-Item -Type Directory $env:SCCACHE_DIR -ErrorAction SilentlyContinue | Out-Null
        }
    }

    foreach($tgt in $targets.GetEnumerator())
    {
        $arch = $($tgt.Name)
        $ossl_target, $tgt_base_suffix = $($tgt.Value)
        Write-Host "Before starting job: ${arch}: $ossl_target, $tgt_base_suffix"
        Start-Job `
            -InitializationScript $funcs `
            -Name "OpenSSL build: $($tgt.Name) ($ossl_target)" `
            -ScriptBlock {$LibSsl = $using:LibSsl; $NoDebugInfo = $using:NoDebugInfo; $NoDeleteBuildDirectories = $using:NoDeleteBuildDirectories; $UseMasm = $using:UseMasm; $UseSccache = $using:UseSccache; BuildAndPlaceOpenSSLLib $using:nasm_details $using:ossl_details $using:arch $using:ossl_target $using:tgt_base_suffix "openssl" $using:staging}
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

    Write-Host -ForegroundColor white "Summary: libssl = $LibSsl, no debug info = $NoDebugInfo, don't delete build directories = $NoDeleteBuildDirectories, use sccache = $UseSccache"

    Stop-Transcript
}
