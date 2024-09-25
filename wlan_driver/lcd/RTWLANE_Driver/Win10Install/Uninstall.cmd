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
    echo UAC.ShellExecute "cmd.exe", "/c %temp%\Win10Install\Uninstall.cmd %params%", "", "runas", 1 >> "%temp%\RtlAdmin.vbs"
    "%temp%\RtlAdmin.vbs"
    popd
    exit /B

:gotAdmin
pushd "%CD%"
CD /D "%~dp0"
:--------------------------------------
echo **************************************************************
echo ***  Batch Uninstall Realtek Wireless LAN Driver               
echo ***                                                            
echo ***  Please wait a moment	                  
echo=

if %PROCESSOR_ARCHITECTURE%==AMD64 (
    set var=Win10x64
    set tools=x64
)
if %PROCESSOR_ARCHITECTURE%==x86 (
    set var=Win10x86
    set tools=x86
)
cd..
set RTWLAN_DRV=%CD%
if NOT exist "%temp%\RtlAdmin.vbs" (
    if exist "Win10\%tools%" (
        xcopy /y "Win10\%tools%" "%var%" /q /s /e /i
        type nul > "%temp%\copyfrombuildfolder.txt"
    )
)
cd %var%
set Drivers=%CD%
cd /d %~dp0
cd %tools%

set logfile="%temp%\Uninstallation_Log.txt"
echo ----- %date% %time% ----- Uninstallation BEGIN > %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_8753*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_B723*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_8179*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_8812*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_8821*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_818B*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_818C*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_B822*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_B814*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_B821*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_C821*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_C82B*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_8813*" >> %logfile%
devcon.exe remove "@PCI\VEN_10EC&DEV_D723*" >> %logfile%

dpinst.exe /Q /D /U "%Drivers%\netrtwlane.inf" >> %logfile%

REM ---> Add delete all netrtwlane.inf here
chcp 65001
set GetVersion=Disable
set deleteDriver=Disable
set RTPublishedName=NULL
FOR /f "tokens=2,3,4 delims=: " %%I IN ('pnputil /enum-drivers') do (
	set PublishedName=!OriginalName!
	set OriginalName=%%J
	if "!OriginalName!"=="netrtwlane.inf" (
		call set RTPublishedName=!PublishedName!
		echo ---^> >> %logfile%
		echo !PublishedName! >> %logfile%
		call set GetVersion=Enable
	)
	if "%%I"=="Version" (
		if "!GetVersion!"=="Enable" (
			echo Driver Version: %%J %%K >> %logfile%
			call set GetVersion=Disable
			call set deleteDriver=Enable
		)
	)
	if "!deleteDriver!"=="Enable" (
		pnputil /delete-driver !RTPublishedName! >> %logfile%
		call set deleteDriver=Disable
		echo ^<--- >> %logfile%
	)
)
REM ---> Add delete all netrtwlane.inf Finish

devcon.exe rescan >> %logfile%
echo ----- %date% %time% ----- Uninstallation END >> %logfile%
type %logfile%
set /p logpath=<"%temp%\batchfilelocation.txt"
if exist "%temp%\batchfilelocation.txt" ( 
    mkdir "%logpath%Log"
    copy /y "%logfile%" "%logpath%Log\Uninstallation_Log.txt"
    del "%temp%\batchfilelocation.txt"
) else (
    mkdir "%~dp0Log"
    copy /y "%logfile%" "%~dp0Log\Uninstallation_Log.txt"
)

popd

echo=
echo **************************************************************
echo ***  Driver Uninstall Finished              
echo ***                                                            
echo ***  Please restart your unit after installation finished                  
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
    rd /s /q "%temp%\%var%"
)
