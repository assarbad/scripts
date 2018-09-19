@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2011..18, Oliver Schneider (assarbad.net) - Released into the PUBLIC DOMAIN.
:::
::: DISCLAIMER: Disclaimer: This software is provided 'as-is', without any
:::             express or implied warranty. In no event will the author be
:::             held liable for any damages arising from the use of this
:::             software.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
setlocal ENABLEEXTENSIONS
:: Look in current directory
set SIGNTOOL=%~dp0signtool.exe
set AC= /ac "%~dp0Certum Trusted Network CA.crt"
:: Check whether the caller wants verbose signtool.exe output
if "%~1" == "-v"        shift&set VERBOSE=1
if "%~1" == "--verbose" shift&set VERBOSE=1
if "%~1" == "/v"        shift&set VERBOSE=1
if "%~1" == "/verbose"  shift&set VERBOSE=1
if "%~1" == "-a"        shift&set APPENDSHA2=1
if "%~1" == "--append"  shift&set APPENDSHA2=1
if "%~1" == "/a"        shift&set APPENDSHA2=1
if "%~1" == "-2"        shift&set SHA2ONLY=1
if "%~1" == "--sha2"    shift&set SHA2ONLY=1
if "%~1" == "/2"        shift&set SHA2ONLY=1
if "%~1" == "" goto :NoFileToSign
:: Check if that succeeds and look for Windows 8.1 SDK (x64) otherwise
"%SIGNTOOL%" /? >NUL 2>NUL || set SIGNTOOL=%ProgramFiles(x86)%\Windows Kits\10\bin\x64\signtool.exe
:: Check if that succeeds and look for Windows 8.1 SDK (x86) otherwise
"%SIGNTOOL%" /? >NUL 2>NUL || set SIGNTOOL=%ProgramFiles(x86)%\Windows Kits\10\bin\x86\signtool.exe
:: Otherwise look for the newest Visual Studio we can get
"%SIGNTOOL%" /? >NUL 2>NUL || call setvcvars.cmd > NUL 2>&1
if not "%VCVER_FRIENDLY%" == "" @(
  echo Using %VCVER_FRIENDLY%
)
set TIMESTAMPSHA1=/tr "http://time.certum.pl"
set TIMESTAMPSHA2=/tr "http://timestamp.digicert.com" /td sha256
set IDENTIFIER=/i Certum%AC%
if not "%~2" == "" @(
  call :SetVar DESCRIPTURL "%~2"
)
if not "%~3" == "" @(
  call :SetVar DESCRIPTION "%~3"
)
set VRFYCMD="%SIGNTOOL%" verify
set SIGNCMD="%SIGNTOOL%" sign /a %IDENTIFIER% /ph
if not "%VERBOSE%" == "" set SIGNCMD=%SIGNCMD% /v /debug
if not "%DESCRIPTURL%" == "" set SIGNCMD=%SIGNCMD% /du "%DESCRIPTURL%"
if not "%DESCRIPTION%" == "" set SIGNCMD=%SIGNCMD% /d "%DESCRIPTION%"
set SIGNCMD=%SIGNCMD%
if not "%SHA2ONLY%" == "1" set APPENDSIG= /as
:: Now sign ...
if not "%SHA2ONLY%" == "1" echo %SIGNCMD% %TIMESTAMPSHA1% "%~1"&%SIGNCMD% %TIMESTAMPSHA1% "%~1"
if not "%APPENDSHA2%%SHA2ONLY%" == "" echo %SIGNCMD% /fd sha256 %TIMESTAMPSHA2%%APPENDSIG% "%~1"&%SIGNCMD% /fd sha256 %TIMESTAMPSHA2%%APPENDSIG% "%~1"
:: And verify
if "%APPENDSHA2%" == "1" %VRFYCMD% /pa /all "%~1"
if not "%APPENDSHA2%" == "1" %VRFYCMD% /kp "%~1"
endlocal&goto :EOF
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
