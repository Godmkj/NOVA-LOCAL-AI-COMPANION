@echo off
title Shutting down NOVA OS
echo Stopping NOVA local background services...

powershell -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*uvicorn main:app*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

echo NOVA services stopped.
timeout /t 2 >nul
exit
