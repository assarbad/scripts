@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
setlocal ENABLEEXTENSIONS
call setvcvars.cmd vs2012 vs2010
if not defined VCVER_FRIENDLY echo VCVER_FRIENDLY is not defined&endlocal&goto :EOF
copy /y %~dp0version.h windows\
devenv %~dp0windows\VS2010\putty.sln /Rebuild "Release|Win32"
endlocal
setlocal ENABLEEXTENSIONS
cd %~dp0windows
for /d %%i in (%~dp0windows\VS2010\*) do @(
    echo %%i
    move /y "%%i\Release\*.exe" "%~dp0"
)
call ollisign.cmd "%~dp0*.exe" "http://www.chiark.greenend.org.uk/~sgtatham/putty/" "Signed PuTTY build (Oliver Schneider)"
set SEVENZIP=%ProgramFiles%\7-Zip\7z.exe
if not exist "%SEVENZIP%" set SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe
if exist "%SEVENZIP%" @(
    "%SEVENZIP%" a -y -t7z "%~dp0putty.7z" "%~dp0*.exe"
)
endlocal
