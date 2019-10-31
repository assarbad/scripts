@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2015-2019, Oliver Schneider (assarbad.net) - PUBLIC DOMAIN/CC0
::: Available from: <https://bitbucket.org/assarbad/scripts/>
:::
::: PURPOSE:    This script tests the setvcvars.cmd script.
:::
::: DISCLAIMER: Disclaimer: This software is provided 'as-is', without any
:::             express or implied warranty. In no event will the author be
:::             held liable for any damages arising from the use of this
:::             software.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
cls
set TESTSTORUN=HelpSwitches VS_nosuch VS2002 VS2003 VS2005 VS2008 VS2010 VS2012 VS2013 VS2015 VS2017 VS2019 VS2005_amd64 VS2008_amd64 VS2010_amd64 VS2012_amd64 VS2013_amd64 VS2015_amd64 VS2017_amd64 VS2019_amd64 VS2005_ia64 VS2008_ia64 VS2010_ia64 VS2012_ia64 VS2013_ia64 VS2015_ia64 VS2017_ia64 VS2019_ia64
for %%i in (%TESTSTORUN%) do @(
  @echo.
  @echo TEST %%i
  prompt $G & call :%%i
  prompt
)
@goto :EOF
:: Check the help switches
:HelpSwitches
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd -h|findstr /l Syntax:
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd --help|findstr /l Syntax:
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd -?|findstr /l Syntax:
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd /h|findstr /l Syntax:
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd /help|findstr /l Syntax:
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:: call /? will show the help for the call command, so we cannot reasonably test that
::
:: Test the known Visual Studio/C++ versions
:VS2002
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2002
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2002
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 7.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2003
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2003
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2003
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 7.1
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2005
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 8.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2008
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 9.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2010
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 10.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2012
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 11.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2013
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 12.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2015
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 14.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2017
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 15.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2019
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 16.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:: Some versions that don't exist
:VS_nosuch
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2001
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2001
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 1
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2300
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2300
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 98
@popd&endlocal
@goto :EOF
:: Checking amd64 toolset on all
:VS2005_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 8.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2008_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 9.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2010_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 10.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2012_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 11.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2013_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 12.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2015_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 14.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2017_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 15.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2019_amd64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 16.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:: Checking ia64 toolset on all
:VS2005_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2005
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 8.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2008_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2008
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 9.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2010_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2010
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 10.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2012_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2012
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 11.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2013_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2013
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 12.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2015_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2015
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 14.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2017_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2017
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 15.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
:VS2019_ia64
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2019
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 16.0
if defined VCVER_FRIENDLY echo VCVER_FRIENDLY=%VCVER_FRIENDLY%
@popd&endlocal
@goto :EOF
