@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2009, Oliver Schneider (assarbad.net) - Released into the PUBLIC DOMAIN.
::: 2010, Christian Wimmer - Adapted from setvcvars.cmd to BCC.
:::
::: PURPOSE:    This script can be used to run the rvars.bat from any of the
:::             Codegear C++ Builder versions from 2009 through 2010 or a
:::             custom given version on the command line.
:::             The script will try to find the newest installed BCC version by
:::             iterating over the space-separated (descending) list of versions
:::             in the variable SUPPORTED_BCC below.
:::             Call it from another script and after that you will have NMAKE
:::             and friends available without having to hardcode their path into
:::             a script or makefile.
:::
::: DISCLAIMER: Disclaimer: This software is provided 'as-is', without any
:::             express or implied warranty. In no event will the author be
:::             held liable for any damages arising from the use of this
:::             software.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:SCRIPT
setlocal & pushd .
set SUPPORTED_BCC=7.0 6.0
reg /? > NUL 2>&1 || echo "REG.EXE is a prerequisite but wasn't found!" && goto :EOF
set SETBCCV_ERROR=0
:: Allow the version to be overridden on the command line
:: ... else find the BCC versions in the order given by SUPPORTED_BCC
if not "%~1" == "" @(
  call :FindBCC "%~1"
) else @(
  for %%i in (%SUPPORTED_BCC%) do @(
    call :FindBCC "%%i"
 )
)
:: Make the string appear a bit nicer
set SUPPORTED_BCC=%SUPPORTED_BCC: =, %
:: Check result and quit with error if necessary
if not defined BCCVARS_PATH @(
  if not "%~1" == "" @(
    echo Requested version ^"%~1^" of C++ Builder not found.
  ) else @(
    echo Could not find any supported version ^(%SUPPORTED_BCC%^) of C++ Builder.
  )
  popd & endlocal & exit /b %SETBCCV_ERROR%
)
:: Return and make sure the outside world sees the results (i.e. leave the scope)
popd & endlocal & if not "%BCCVARS_PATH%" == "" @(call "%BCCVARS_PATH%") & if not "%BCCVER_FRIENDLY%" == "" set BCCVER_FRIENDLY=%BCCVER_FRIENDLY%
goto :EOF

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: / FindBCC subroutine
:::   Param1 == version identifier for BCC
:::
:::   Sets the global variable BCCVARS_PATH if it finds the installation.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:FindBCC
setlocal ENABLEEXTENSIONS & set BCCVER=%~1
:: We're not interested in overwriting an already existing value
if defined BCCVARS_PATH @( endlocal & goto :EOF )
set _BCCINSTALLKEY=HKEY_CURRENT_USER\Software\CodeGear\BDS\%BCCVER%
echo Trying to find C++ Builder %BCCVER%
for /f "tokens=2*" %%i in ('reg query "%_BCCINSTALLKEY%" /v RootDir 2^> NUL') do @(
  call :SetVar _BCCINSTALLDIR "%%j"
)
set _BCCINSTALLKEY=HKEY_CURRENT_USER\SOFTWARE\CodeGear\BDS\%BCCVER%
:: If we haven't found it by now, try the WOW64 "Software" key
if not defined _BCCINSTALLDIR @(
  for /f "tokens=2*" %%i in ('reg query "%_BCCINSTALLKEY%" /v RootDir 2^> NUL') do @(
    call :SetVar _BCCINSTALLDIR "%%j"
  )
)
if defined _BCCINSTALLDIR @(
  if EXIST "%_BCCINSTALLDIR%\bin\rsvars.bat" @(
    call :SetVar BCCVARS_PATH "%_BCCINSTALLDIR%\bin\rsvars.bat"
  )
REM  if not defined BCCVARS_PATH if EXIST "%_BCCINSTALLDIR%\vcvarsall.bat" @(
REM    call :SetVar BCCVARS_PATH "%_BCCINSTALLDIR%\vcvarsall.bat"
REM  )
)
:: Return, in case nothing was found
if not defined BCCVARS_PATH @( endlocal&set SETBCCV_ERROR=1&goto :EOF )
:: Replace the . in the version by an underscore
set BCCVERLBL=%BCCVER:.=_%
:: Try to set a friendlier name for the Visual Studio version
call :FRIENDLY_%BCCVERLBL% > NUL 2>&1
:: Jump over those "subs"
goto :FRIENDLY_SET
:FRIENDLY_6_0
    set _BCCVER=2009

    goto :EOF
:FRIENDLY_7_0
    set _BCCVER=2010
    goto :EOF
:FRIENDLY_SET
if not defined _BCCVER call :SetVar _BCCVER "%BCCVER%"
echo   -^> Found Builder C++ %_BCCVER%
endlocal & set BCCVARS_PATH=%BCCVARS_PATH%&set BCCVER_FRIENDLY=C++ Builder %_BCCVER%
goto :EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: \ FindBCC subroutine
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: / SetVar subroutine
:::   Param1 == name of the variable, Param2 == value to be set for the variable
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:SetVar
:: Get the name of the variable we are working with
setlocal ENABLEEXTENSIONS&set VAR_NAME=%1
endlocal & set %VAR_NAME%=%~2
goto :EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: \ SetVar subroutine
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
