@echo off
rem ============================================================================
rem  Yaro - apply the Yaro settings to an ALREADY INSTALLED Windows 11.
rem  Read README.md first. Options are at the top of scripts\Specialize.ps1.
rem  Logs: C:\Windows\Setup\Scripts\Yaro\
rem ============================================================================
net session >nul 2>&1 || (powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)
title Yaro - apply settings
echo.
echo  Yaro will remove apps, change services and many Windows settings.
echo  Close this window now if you have not read README.md.
echo.
pause
echo [1/3] Creating a restore point (only if System Protection is on)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before Yaro' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue"
echo [2/3] System settings (this can take several minutes)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Specialize.ps1" -Live
echo [3/3] Settings of the current user...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\FirstLogon.ps1"
echo.
echo  Done. Restart Windows to finish. Logs: C:\Windows\Setup\Scripts\Yaro\
echo.
pause
