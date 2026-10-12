@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0uruchom-windows.ps1" -Compatibility %*
if errorlevel 1 pause
