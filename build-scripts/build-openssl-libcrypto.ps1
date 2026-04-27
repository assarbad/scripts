#Requires -Version 6.0
[CmdletBinding()]
param(
    [switch]$LibSsl = $false,
    [switch]$NoDebugInfo = $false,
    [switch]$NoDeleteBuildDirectories = $false,
    [switch]$UseMasm = $false,
    [switch]$UseSccache = $false,
    [switch]$NoJobs = $false,
    [ValidateSet("x86", "x64", "all" , "both", "native")] [string]$ArchToBuild = "native"
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

$openssl30x = @{ # LTS, Sep 2026
    "3.0.20" = @{
        "sha256" = "c80a01dfc70ece4dc21168932c37739042d404d46ccc81a5986dd75314ecda6f";
        "urltpl" = "https://github.com/openssl/openssl/releases/download/openssl-{0}/openssl-{0}.tar.gz"
    }
}
$openssl35x = @{ # LTS, April 2030
    "3.5.6" = @{
        "sha256" = "deae7c80cba99c4b4f940ecadb3c3338b13cb77418409238e57d7f31f2a3b736";
        "urltpl" = "https://github.com/openssl/openssl/releases/download/openssl-{0}/openssl-{0}.tar.gz"
    }
}
$openssl40x = @{ # non-LTS
    "4.0.0" = @{
        "sha256" = "c32cf49a959c4f345f9606982dd36e7d28f7c58b19c2e25d75624d2b3d2f79ac";
        "urltpl" = "https://github.com/openssl/openssl/releases/download/openssl-{0}/openssl-{0}.tar.gz"
    }
}
$nasm = @{
    "3.01" = @{
        "sha256" = "e0ba5157007abc7b1a65118a96657a961ddf55f7e3f632ee035366dfce039ca4";
        "urltpl" = "https://www.nasm.us/pub/nasm/releasebuilds/{0}/win64/nasm-{0}-win64.zip"
    }
}
$openssl = $openssl35x

<#
.Description
Downloads a file using Invoke-WebRequest. This is suboptimal, but should be okay for this sort of script.
#>
function Download-File
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
function Download-OpenSSL-Version
{
    param(
        [Parameter(Mandatory=$true)]  [String]$version,
        [Parameter(Mandatory=$true)]  [hashtable]$details,
        [Parameter(Mandatory=$true)]  [String]$tgtdir
    )

    $knownhash = $details.sha256
    $url = $details.urltpl -f $version
    $fname = Split-Path -Path $url -Leaf
    if (Test-Path -Path "$tgtdir\$fname" -PathType Leaf)
    {
        Write-Host -ForegroundColor yellow "Note: using existing file $tgtdir\$fname. If this is not desired, remove it prior to running this script."
    }
    else
    {
        $host.ui.WriteErrorLine("Downloading OpenSSL $version from $url as $fname (into $tgtdir)")
        Download-File $url "$tgtdir\$fname"
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
function Download-NASM-Version
{
    param(
        [Parameter(Mandatory=$true)]  [String]$version,
        [Parameter(Mandatory=$true)]  [hashtable]$details,
        [Parameter(Mandatory=$true)]  [String]$tgtdir
    )

    $knownhash = $details.sha256
    $url = $details.urltpl -f $version
    $fname = Split-Path -Path $url -Leaf
    if (Test-Path -Path "$tgtdir\$fname" -PathType Leaf)
    {
        Write-Host -ForegroundColor yellow "Note: using existing file $tgtdir\$fname. If this is not desired, remove it prior to running this script."
    }
    else
    {
        $host.ui.WriteErrorLine("Downloading NASM $version from $url as $fname (into $tgtdir)")
        Download-File $url "$tgtdir\$fname"
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
    function Import-OpenSSL
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
    function Import-NASM
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
    function Get-VS-BasePath
    {
        param($vsrange = "[16.0,18.0)")

        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        $vspath = & $vswhere -products "*" -format value -property installationPath -latest -version "$vsrange"
        ThrowOnNativeFailure "Failed to retrieve path to Visual Studio installation (range: $vsrange)"
        return $vspath
    }

    function Copy-Finished
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
    function Patch-Makefile
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
    function Get-FileName-From-TargetName
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
    function Build-And-Place-OpenSSL-Lib
    {
        param(
            [Parameter(Mandatory=$true)]  [hashtable]$nasm,
            [Parameter(Mandatory=$true)]  [hashtable]$ossl,
            [Parameter(Mandatory=$true)]  [String]$perl,
            [Parameter(Mandatory=$true)]  [String]$arch,
            [Parameter(Mandatory=$true)]  [String]$ossl_target,
            [Parameter(Mandatory=$true)]  [String]$tgt_base_suffix,
            [Parameter(Mandatory=$true)]  [String]$ossl_hdrs,
            [Parameter(Mandatory=$true)]  [String]$staging
        )
        $blddir = "$staging\$ossl_target.$pid"
        $oldenv = Get-ChildItem env:
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

            if ($script:UseMasm)
            {
                $configure_ossl_target = "${ossl_target}-masm"
                Write-Host -ForegroundColor white "Using MASM"
            }
            else
            {
                $configure_ossl_target = $ossl_target
                $nasmdir = Import-NASM $nasm $blddir
                # Make our copy of NASM available
                $env:PATH =  $nasmdir + ";" + $env:PATH
                Write-Host -ForegroundColor white "NASM: $nasmdir"
            }

            $vspath = Get-VS-BasePath
            Import-Module "$vspath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll" -Force -cmdlet Enter-VsDevShell
            Enter-VsDevShell -VsInstallPath "$vspath" -DevCmdArguments "-arch=$arch -no_logo" -SkipAutomaticLocation
            $ossldir = Import-OpenSSL $ossl $blddir
            Write-Host -ForegroundColor white "OpenSSL dir: $ossldir"
            Push-Location -Path "$ossldir"

            $target_fname = Get-FileName-From-TargetName "libcrypto.lib" $tgt_base_suffix
            Write-Host "Target file name for lib: $target_fname"

            $env:LOG_BUILD_COMMANDLINES="$blddir\buildcmdlines.log"
            $sentinel_files = @("INSTALL.md", "INSTALL")
            $srcepoch = $null
            foreach ($sfile in $sentinel_files)
            {
                try
                {
                    $srcepoch = ([DateTimeOffset](Get-Item "$pwd\$sfile").LastWriteTime).ToUnixTimeSeconds()
                    break
                }
                catch
                {
                    continue
                }
            }
            if ($srcepoch -eq $null)
            {
                throw "Unable to retrieve a sensible timestamp from the unpacked archive."
            }
            $env:SOURCE_DATE_EPOCH="$srcepoch"

            # Probably a good idea also to add (needs to be validated!): no-autoalginit no-autoerrinit
            Invoke-Configure $perl $configure_ossl_target --api=1.1.0 --release threads no-shared no-filenames | Out-Host
            ThrowOnNativeFailure "Failed to configure OpenSSL for build ($configure_ossl_target, $arch, $target_fname)"
            Write-Host -ForegroundColor white "${arch}: libssl = $script:LibSsl, no debug info = $script:NoDebugInfo, don't delete build directories = $script:NoDeleteBuildDirectories, use sccache = $script:UseSccache"
            if ($script:UseSccache -And (Test-Path -Path "$staging\bin\cl.exe" -PathType Leaf))
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
            if ($script:NoDebugInfo)
            {
                Patch-Makefile
                $env:_CL_="/d1trimfile:'$blddir' /Brepro"
                $env:_ML_="/Brepro"
            }
            else
            {
                Patch-Makefile
                $env:_CL_="/d1trimfile:'$blddir' /Brepro /Z7"
                $env:_ML_="/Brepro /Zi"
            }
            if ($script:LibSsl)
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
            Copy-Finished .\libcrypto.lib "$libpath\$target_fname"
            if ($script:LibSsl)
            {
                $target_fname2 = Get-FileName-From-TargetName "libssl.lib" $tgt_base_suffix
                Copy-Finished .\libssl.lib "$libpath\$target_fname2"
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
            Write-Host -ForegroundColor white "${arch}: libssl = $script:LibSsl, no debug info = $script:NoDebugInfo, don't delete build directories = $script:NoDeleteBuildDirectories, use sccache = $script:UseSccache"
            if ($script:NoDeleteBuildDirectories)
            {
                Write-Host -ForegroundColor green "Keeping build directory $blddir ($script:NoDeleteBuildDirectories)"
            }
            else
            {
                Write-Host -ForegroundColor yellow "Removing build directory $blddir ($script:NoDeleteBuildDirectories)"
            }
        }
    }

    <#
    .Description
    Attempts to detect Git for Windows based on heuristics and returns the common root of the cmd and bin subdirectories.
    #>
    function Get-GitForWindows-Root
    {
        $gitexe = Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue
        if ($gitexe)
        {
            $gitcmdbin = Split-Path -Path $gitexe.Source
            if ((Split-Path -Path $gitcmdbin -Leaf) -in @("cmd", "bin"))
            {
                return (Split-Path -Path $gitcmdbin)
            }
        }
        return $null
    }

    <#
    .Description
    Returns the full path to bin\sh.exe underneath the Git for Windows installation root.
    #>
    function Get-GitForWindows-sh
    {
        $gitfwroot = Get-GitForWindows-Root
        if ($gitfwroot)
        {
            $shexe = "$gitfwroot\bin\sh.exe"
            if (Test-Path -Path "$shexe" -PathType Leaf)
            {
                return $shexe
            }
        }
        return $null
    }

    <#
    .Description
    Retrieves  if Perl is available and if not found kicks off an _interactive_ installation of StrawberryPerl via winget (i.e. user can still choose to cancel).
    #>
    function Get-Available-Perl
    {
        $perl = Get-Command -Name perl -CommandType Application -ErrorAction SilentlyContinue
        <#
        if (-not $perl)
        {
            $shexe = Get-GitForWindows-sh
            if ($shexe)
            {
                & $shexe -c "perl --version" *>&1 | Out-Null
                if ($LASTEXITCODE -eq 0)
                {
                    Write-Host "Found Perl via Git for Windows (${shexe} -> perl)"
                    return @{ Path = $shexe; UseShim = $true }
                }
            }
        }
        else
        {
            Write-Host "Found Perl via PATH ($($perl.Source))"
            return @{ Path = $perl.Source; UseShim = $false }
        }
        #>
        if (-not $perl)
        {
            echo "NOTE: You need to have Perl installed for this build for work. Kicking off the installation. Feel free to cancel, but be aware that the build will fail."
            winget install --accept-package-agreements --accept-source-agreements --exact --interactive --id StrawberryPerl.StrawberryPerl
            $perl = Get-Command perl -CommandType Application -ErrorAction SilentlyContinue
            if ($perl -eq $null)
            {
                throw "Perl not available and wasn't installed by the user"
            }
        }
        return $perl
    }

    <#
    .Description
    Prepare the util/perl sudirectory inside the unpacked OpenSSL so that it has modules that don't come with Git for Windows.
    #>
    function Prepare-Perl-from-GitForWindows
    {
        param(
            [Parameter(Mandatory=$true)]  [String]$tgtdir
        )
        $modules = @(
            @{
                "sha256" = "b009ff51f4fb108d19961a523e99b4373ccf958d37ca35bf1583215908dca9a9";
                "url" = "https://cpan.metacpan.org/authors/id/J/JE/JESSE/Locale-Maketext-Simple-0.21.tar.gz"
            }
        )
        foreach ($module in $modules) {
            $knownhash = $module.sha256
            $url = $module.url
            $fname = Split-Path -Path $url -Leaf
            if (Test-Path -Path "$tgtdir\$fname" -PathType Leaf)
            {
                Write-Host -ForegroundColor yellow "Note: using existing file $tgtdir\$fname. If this is not desired, remove it prior to running this script."
            }
            else
            {
                $host.ui.WriteErrorLine("Downloading $url as $fname (into $tgtdir)")
                Download-File $url "$tgtdir\$fname"
            }
            $hash = (Get-FileHash -Algorithm SHA256 -Path "$tgtdir\$fname").Hash
            if ($knownhash -eq $hash)
            {
                Write-Host -ForegroundColor green "`tFile $fname downloaded and hash matches."
            }
            else
            {
                throw "The expected ($knownhash) and actual hashes ($hash) don't match for $fname!"
            }
            $host.ui.WriteErrorLine("Unpacking  $fname")
            Push-Location $tgtdir
            try
            {
                tar -xf "$tgtdir\$fname"
            } finally {
                Pop-Location
            }
            $subdir = $fname -replace '\.tar\.gz$', ''
            if (!(Test-Path -Path "$tgtdir\$subdir"))
            {
                throw "Expected to find a folder named '$tgtdir\$subdir' after unpacking the archive."
            }
            Copy-Item -Recurse "$tgtdir\$subdir\lib\*" "$pwd\util\perl\"
            if (-not $?)
            {
                throw "Copying of the subdirectory from lib to util/perl failed."
            }
        }
    }

    <#
    .Description
    Invokes either Perl from Git for Windows or a full-fledged Perl
    #>
    function Invoke-Configure
    {
        param(
            [Parameter(Mandatory=$true)]  [String]$perl,
            [Parameter(ValueFromRemainingArguments)][string[]]$args
        )
        Write-Host "Executing equivalent of: perl Configure $($args | %{ "'$_'" })"
        $cmdout = & "$perl" Configure @args *>&1
        if ($LASTEXITCODE -ne 0)
        {
            $cmdout | Write-Warning
        }
    }
} # $funcs

<#
.Description
Patches the openssl/{configuration,opensslconf}.h to unify the x86 and x64 headers generated during the OpenSSL builds.
#>
function Patch-Configuration-Header
{
    param(
        [Parameter(Mandatory=$true)]  [String]$srcfile,
        [Parameter(Mandatory=$true)]  [String]$tgtfile
    )

    $fname = Split-Path "$srcfile" -Leaf
    if ($fname in @("opensslconf.h", "configuration.h"))
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
                    Patch-opensslconf-Header "$($hash.Path)" "$incdir\$fname"
                }
            }
        }
    }
}

try
{
    if ($nasm.Count -ne 1)
    {
        Write-Error "There is more than a single version defined for NASM in \$nasm."
        exit 1
    }
    if ($openssl.Count -ne 1)
    {
        Write-Error "There is more than a single version defined for OpenSSL in \$openssl."
        exit 1
    }
    if ($ArchToBuild -eq "native")
    {
        $oldvalue = $ArchToBuild
        if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64")
        {
            $ArchToBuild = "x64"
        }
        elseif ($env:PROCESSOR_ARCHITECTURE -eq "x86")
        {
            $ArchToBuild = "x64"
        }
        Write-Host -ForegroundColor white "Target architecture was set to ${oldvalue}: ended up picking '$ArchToBuild'"
    }

    $targets = @{ x86=@("VC-WIN32", "32"); x64=@("VC-WIN64A", "64") }
    $logpath = "$PSScriptRoot\build-openssl-libcrypto.log"
    $staging = "$pwd\staging"
    Start-Transcript -Path $logpath -Append

    . $funcs
    $perl = Get-Available-Perl
    if (-not $perl)
    {
        Write-Error "No suitable Perl found. Perhaps install one using:`n`twinget install --accept-package-agreements --accept-source-agreements --exact --interactive --id StrawberryPerl.StrawberryPerl"
        exit 1
    }

    # Cache copies of the files we need for the build
    if ($UseMasm)
    {
        $nasm_details = @{ }
    }
    else
    {
        foreach($version in $nasm.keys)
        {
            $nasm_details = Download-NASM-Version $version $nasm[$version] "$staging"
            break # use the first one always
        }
    }
    foreach($version in $openssl.keys)
    {
        $ossl_details = Download-OpenSSL-Version  $version $openssl[$version] "$staging"
        break # use the first one always
    }

    Write-Host -ForegroundColor white "Going to build: libssl = $LibSsl, no debug info = $NoDebugInfo, don't delete build directories = $NoDeleteBuildDirectories, use sccache = $UseSccache"

    if ($UseSccache)
    {
        try
        {
            $ccache = (Get-Command sccache -CommandType Application -ErrorAction SilentlyContinue).Path
            Write-Host -ForegroundColor white "Using sccache: $ccache"
            $fakebindir = "$staging\bin"
            New-Item -Type Directory $fakebindir -ErrorAction SilentlyContinue | Out-Null
            Copy-Item -Force "$ccache" "$fakebindir\cl.exe"
            New-Item -Type Directory "$staging\sccache" -ErrorAction SilentlyContinue | Out-Null
        }
        catch
        {
            $UseSccache = $false
            $fakebindir = $null
            Write-Warning "Cannot use sccache"
        }
    }

    foreach($tgt in $targets.GetEnumerator())
    {
        $arch = $($tgt.Name)
        if (($ArchToBuild -ne "all") -and ($ArchToBuild -ne "both") -and ($arch -ne $ArchToBuild))
        {
            Write-Host "Skipping build for: ${arch} (requested: ${ArchToBuild})"
            continue;
        }
        $ossl_target, $tgt_base_suffix = $($tgt.Value)
        if ($NoJobs)
        {
            $oldpwd = $pwd
            $oldenv = Get-ChildItem env:
            try
            {
                $oldenv|%{ Set-Item -Path "Env:$($_.Name)" "$($_.Value)" }
                Write-Host "Before starting build: ${arch}: $ossl_target, $tgt_base_suffix"
                Build-And-Place-OpenSSL-Lib $nasm_details $ossl_details $perl $arch $ossl_target $tgt_base_suffix "openssl" $staging
            }
            finally
            {
                cd $oldpwd
                $oldenv|%{ Set-Item -Path "Env:$($_.Name)" "$($_.Value)" }
            }
        }
        else
        {
            Write-Host "Before starting job: ${arch}: $ossl_target, $tgt_base_suffix"
            Start-Job `
                -InitializationScript $funcs `
                -Name "OpenSSL build: $($tgt.Name) ($ossl_target)" `
                -ScriptBlock {$LibSsl = $using:LibSsl; $NoDebugInfo = $using:NoDebugInfo; $NoDeleteBuildDirectories = $using:NoDeleteBuildDirectories; $UseMasm = $using:UseMasm; $UseSccache = $using:UseSccache; Build-And-Place-OpenSSL-Lib $using:nasm_details $using:ossl_details $using:perl $using:arch $using:ossl_target $using:tgt_base_suffix "openssl" $using:staging}
        }
    }

    if (-Not ($NoJobs))
    {
        while (Get-Job -State "Running")
        {
            Clear-Host
            Get-Job|%{ $runtime = "{0:hh}:{0:mm}:{0:ss}" -f ([datetime]::now - $_.PSBeginTime); Write-Host "$($_.Id): $($_.Name) -> $($_.State), $runtime" }
            Start-Sleep 2
        }
    }

    FinalizeHeaders $targets
}
finally
{
    if (-Not ($NoJobs))
    {
        # Write output from the jobs (commented out, because we have a log file)
        Get-Job | Receive-Job
        Get-Job | %{ $duration = $_.PSEndTime - $_.PSBeginTime; Write-Host "$($_.Name) took $duration" }
        # Remove jobs from queue
        Get-Job | Remove-Job
    }

    Write-Host -ForegroundColor white "Summary: libssl = $LibSsl, no debug info = $NoDebugInfo, don't delete build directories = $NoDeleteBuildDirectories, use sccache = $UseSccache"

    Stop-Transcript
}
