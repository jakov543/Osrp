@echo off
title OSRP ^| Osijek Roleplay server
set BASE=%~dp0OSRP-Server
if not exist "%BASE%\artifacts\FXServer.exe" (
  echo Prvo pokreni setup-server.bat
  pause
  exit /b 1
)
cd /d "%BASE%\server-data"
"%BASE%\artifacts\FXServer.exe" +exec server.cfg
pause
