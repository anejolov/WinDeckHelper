@echo off
CLS
setlocal enabledelayedexpansion

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    pushd "%CD%"
    CD /D "%~dp0"
    if %PROCESSOR_ARCHITECTURE%==AMD64 (
        set var=Win10x64
        set arch=x64
    )
    if %PROCESSOR_ARCHITECTURE%==x86 (
        set var=Win10x86
        set arch=x86
    )
    cd..
    xcopy /y "Win10\%arch%" "%temp%\%var%\" /s /e /i
    xcopy /y "%var%" "%temp%\%var%\" /s /e /i
    xcopy /y "Win10Install" "%temp%\Win10Install\*.*" /s /e /i
    echo %~dp0> "%temp%\batchfilelocation.txt"
    CLS
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\RtlAdmin.vbs"
    set params = %*:"=""
    echo UAC.ShellExecute "cmd.exe", "/c %temp%\Win10Install\Install.cmd %params%", "", "runas", 1 >> "%temp%\RtlAdmin.vbs"
    "%temp%\RtlAdmin.vbs"
    popd
    exit /B

:gotAdmin
pushd "%CD%"
CD /D "%~dp0"
:--------------------------------------

echo **************************************************************
echo ***  Batch Install Realtek Wireless LAN Driver               
echo ***                                                            
echo ***  Please wait a moment	                  
echo=

if %PROCESSOR_ARCHITECTURE%==AMD64 (
    set var=Win10x64
    set arch=x64
)
if %PROCESSOR_ARCHITECTURE%==x86 (
    set var=Win10x86
    set arch=x86
)
cd..
set RTWLAN_DRV=%CD%
if NOT exist "%temp%\RtlAdmin.vbs" ( 
    if exist "Win10\%arch%" (
        xcopy /y "Win10\%arch%" "%var%" /q /s /e /i
        type nul > "%temp%\copyfrombuildfolder.txt"
    )
)
cd %var%
set logfile="%temp%\Installation_Log.txt"
echo ----- %date% %time% ----- Installation BEGIN > %logfile%
pnputil /add-driver "netrtwlane.inf" /install >> %logfile%
echo ----- %date% %time% ----- Installation END >> %logfile%
type %logfile%
set /p logpath=<"%temp%\batchfilelocation.txt"
if exist "%temp%\batchfilelocation.txt" ( 
    mkdir "%logpath%Log"
    copy /y "%logfile%" "%logpath%Log\Installation_Log.txt"
    del "%temp%\batchfilelocation.txt"
) else (
    mkdir "%~dp0Log"
    copy /y "%logfile%" "%~dp0Log\Installation_Log.txt"
)

popd

echo=     
echo **************************************************************
echo ***  Driver Install Finished                                       
echo=

pause
del "%logfile%"
if NOT exist "%temp%\RtlAdmin.vbs" ( 
    if exist "%temp%\copyfrombuildfolder.txt" (
        rd /s /q "%RTWLAN_DRV%\%var%"
        del "%temp%\copyfrombuildfolder.txt"
    )
)
if exist "%temp%\RtlAdmin.vbs" ( 
    del "%temp%\RtlAdmin.vbs"
    rd /s /q "%temp%\Win10Install"
    rd /s /q  "%temp%\%var%"
)
