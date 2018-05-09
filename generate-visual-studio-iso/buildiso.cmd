@echo off
:: Create the folder which will be made into an ISO with:
::   vs_Professional.exe --layout %CD%\vs2017pro --lang en-US
::   vs_BuildTools.exe --layout %CD%\vs2017bldtools --lang en-US
if not exist "%~dp0oscdimg.exe" echo Could not find oscdimg.exe next to this script in %~dp0&exit /b 1
set IMGLABEL=%~1
if "%IMGLABEL%" == "" echo You need to give a label for the image to be created&exit /b 1
set VSDIR=%~2
if not exist "%VSDIR%" echo The folder supposed to contain the offline installation components ^(%VSDIR%^) does not exist&exit /b 1
xcopy /y "%~dpnx0" "%VSDIR%\"
if not exist "%VSDIR%\%~nx0" echo Could not copy %~nx0 into %VSDIR%&exit /b 1
xcopy /y "%~dp0oscdimg.exe" "%VSDIR%\"
if not exist "%VSDIR%\oscdimg.exe" echo Could not copy oscdimg.exe into %VSDIR%&exit /b 1
:: -oc This option will encode duplicate files only once.  It does
::     a binary compare on the files and is slower.
:: -g  This option  makes all times encoded in GMT time rather than the
::     local time.
:: -h  This option will include all hidden files and directories under the
::     source path for this image.
:: -l  This options specifies the volume label.  This should be 32
::     characters or less.  There is no space after this option.
::     Example: -lMyVolume
:: -u2  This option is used to produce an image that has only the UDF
::      file system on it.  Any system not capable of reading UDF will
::      only see a default text file alerting the user that this image is
::      only available on computers that support UDF.
:: -yl  This option will use long allocation descriptors instead of short
::      allocation descriptors.
::  Writes UDF revision 2.00  (Supported: Windows XP and later)
@echo on
"%~dp0oscdimg.exe" -oc -g -h -l%IMGLABEL% -u2 -yl -udfver200 "%VSDIR%" "%VSDIR%.iso"
@echo off
