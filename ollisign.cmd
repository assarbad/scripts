@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2011/15, Oliver Schneider (assarbad.net) - Released into the PUBLIC DOMAIN.
:::
::: DISCLAIMER: Disclaimer: This software is provided 'as-is', without any
:::             express or implied warranty. In no event will the author be
:::             held liable for any damages arising from the use of this
:::             software.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
if "%~1" == "" goto :NoFileToSign
call setvcvars.cmd > NUL 2>&1
set TIMESTAMP=/t "http://timestamp.verisign.com/scripts/timstamp.dll"
set IDENTIFIER=/sm /r VeriSign /ac %~dp0\MSCV-VSClass3.cer
if not "%~2" == "" @(
  call :SetVar DESCRIPTURL "%~2"
)
if not "%~3" == "" @(
  call :SetVar DESCRIPTION "%~3"
)
set VRFYCMD=signtool.exe verify /pa "%~1"
set SIGNCMD=signtool.exe sign /a %IDENTIFIER% /ph
if not "%DESCRIPTURL%" == "" set SIGNCMD=%SIGNCMD% /du "%DESCRIPTURL%"
if not "%DESCRIPTION%" == "" set SIGNCMD=%SIGNCMD% /d "%DESCRIPTION%"
set SIGNCMD=%SIGNCMD% %TIMESTAMP% "%~1"
:: Now sign ...
echo %SIGNCMD%
%SIGNCMD%
:: And verify
%VRFYCMD%
goto :EOF
:NoFileToSign
echo ERROR: Need to give a file to sign!
echo.
echo   Syntax:
echo.
echo   ollisign ^<file^|wildcard^> ^[url^] ^[description^]
exit /b 1
goto :EOF

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
