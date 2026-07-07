@echo off
title NOVA Desktop Launcher
cd /d "%~dp0"

echo Starting NOVA desktop app...
start "NOVA Desktop" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0NOVA_Desktop.ps1"
exit
