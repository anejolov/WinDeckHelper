@echo off
pushd %~dp0Data\
PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& .\Windeckhelper.ps1" 
popd