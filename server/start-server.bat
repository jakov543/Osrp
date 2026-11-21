@echo off
title OSRP ^| Osijek Roleplay server (24/7)
set BASE=%~dp0OSRP-Server
if not exist "%BASE%\artifacts\FXServer.exe" (
  echo Prvo pokreni setup-server.bat
  pause
  exit /b 1
)
cd /d "%BASE%\server-data"

:loop
echo.
echo [OSRP] Server se pokrece... %date% %time%
"%BASE%\artifacts\FXServer.exe" +exec server.cfg
echo.
echo [OSRP] Server se ugasio. Ponovno pokretanje za 10 sekundi... (zatvori prozor za potpuno gasenje)
timeout /t 10 /nobreak >nul
goto loop
