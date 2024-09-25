@echo off
pushd %~dp0
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& .\Windeckhelper.ps1" 
popd