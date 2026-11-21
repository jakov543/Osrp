@echo off
title OSRP server setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-server.ps1"
echo.
pause
