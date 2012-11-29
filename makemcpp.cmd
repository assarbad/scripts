@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: 2009, Oliver Schneider (assarbad.net) - Released into the PUBLIC DOMAIN.
:::
::: PURPOSE:    This script can be used to build MCPP using Visual C++.
:::
::: DISCLAIMER: Disclaimer: This software is provided 'as-is', without any
:::             express or implied warranty. In no event will the author be
:::             held liable for any damages arising from the use of this
:::             software.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:SCRIPT
setlocal ENABLEDELAYEDEXPANSION & pushd .
set SUPPORTED_VC=9.0 8.0 7.1 7.0
reg /? > NUL 2>&1 || echo "REG.EXE is a prerequisite but wasn't found!" && goto :EOF
:: Set the variables for VC by calling the respective .bat script
call setvcvars.cmd "%~1"
:: Prepare the config file
set CONF_FILE=src\noconfig.h
set TARG_FILENAME=msvc_config.h
set TARG_FILE=src\%TARG_FILENAME%
:: If the noconfig.h does not exist, look for the backup copy and use it if it's
:: found, otherwise bail out with an error message!
if not exist "%CONF_FILE%" (
    if exist "%CONF_FILE%.bak" (
        echo Will use backup copy ...
        copy /y "%CONF_FILE%.bak" "%CONF_FILE%" > NUL 2>&1
        del /f "%TARG_FILE%" > NUL 2>&1
    ) else (
        echo ERROR: ^"%CONF_FILE%^" does not exist and no backup copy is available!!!
        goto :NOP_EXIT
    )
)
if exist "%TARG_FILE%" (echo Will not overwrite existing %TARG_FILENAME% ... & goto :NO_CONFIG_CREATE)
:: Empty the target file
echo.> "%TARG_FILE%"
for /f "tokens=1,2,*" %%a in (%CONF_FILE%) do @(
    if "%%a"=="#define" (
        if "%%b"=="HOST_COMPILER" (
            echo %%a %%b MSC>> "%TARG_FILE%"
        ) else if "%%b"=="VERSION_MSG" (
            echo %%a %%b ^"%VCVER_FRIENDLY%^">> "%TARG_FILE%"
        ) else if "%%b"=="SYSTEM" (
            echo %%a %%b SYS_WIN32>> "%TARG_FILE%"
        ) else if "%%b"=="COMPILER_EXT_VAL" (
            echo %%a %%b _STRING_CHEAT_^(_MSC_VER^)>> "%TARG_FILE%"
        ) else if "%%b"=="COMPILER_EXT2_VAL" (
            echo %%a %%b _STRING_CHEAT_^(_MSC_FULL_VER^)>> "%TARG_FILE%"
        ) else (
            echo %%a %%b %%c>> "%TARG_FILE%"
        )
    ) else (
        echo %%a %%b %%c>> "%TARG_FILE%"
    )
)
:: Take a backup copy of the noconfig.h file
if not exist "%CONF_FILE%.bak" copy /y "%CONF_FILE%" "%CONF_FILE%.bak" > NUL 2>&1
:: Now overwrite it ...
echo // Auto-generated include file %~nx0> "%CONF_FILE%"
echo #define __STRING_CHEAT__^(x^) #x>> "%CONF_FILE%"
echo #define _STRING_CHEAT_^(x^)   __STRING_CHEAT__^(x^)>> "%CONF_FILE%"
echo #include ^"%TARG_FILENAME%^">> "%CONF_FILE%"
:NO_CONFIG_CREATE
pushd .\src
set CPPFLAGS=/nologo
set CFLAGS=/nologo
set LINKFLAGS=/nologo
set BINDIR=..\bin
nmake.exe /nologo /f ..\noconfig\visualc.mak mcpp.exe
popd
:NOP_EXIT
popd & endlocal & goto :EOF

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
