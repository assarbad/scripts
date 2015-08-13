@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2015, Oliver Schneider (assarbad.net) - PUBLIC DOMAIN/CC0
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
:: Check the help switches
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd -h
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd --help
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd /h
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd /help
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd -?
@popd&endlocal
:: call /? will show the help for the call command, so we cannot reasonably test that
:: Test the known Visual Studio/C++ versions
:: 2002
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2002
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2002
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 7.0
@popd&endlocal
:: 2003
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2003
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2003
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 7.1
@popd&endlocal
:: 2005
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 8.0
@popd&endlocal
:: 2008
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 9.0
@popd&endlocal
:: 2010
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 10.0
@popd&endlocal
:: 2012
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 11.0
@popd&endlocal
:: 2013
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 12.0
@popd&endlocal
:: 2015
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 14.0
@popd&endlocal
:: Some versions that don't exist
:: 2001
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2001
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 2001
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 1
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2300
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd vs2300
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd 98
@popd&endlocal
:: Checking amd64 toolset on all
:: 2005
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 8.0
@popd&endlocal
:: 2008
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 9.0
@popd&endlocal
:: 2010
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 10.0
@popd&endlocal
:: 2012
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 11.0
@popd&endlocal
:: 2013
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 12.0
@popd&endlocal
:: 2015
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 vs2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd amd64 14.0
@popd&endlocal
:: Checking ia64 toolset on all
:: 2005
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2005
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 8.0
@popd&endlocal
:: 2008
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2008
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 9.0
@popd&endlocal
:: 2010
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2010
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 10.0
@popd&endlocal
:: 2012
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2012
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 11.0
@popd&endlocal
:: 2013
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2013
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 12.0
@popd&endlocal
:: 2015
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 vs2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 2015
@popd&endlocal
@setlocal&pushd .&echo on
call %~dp0setvcvars.cmd ia64 14.0
@popd&endlocal
