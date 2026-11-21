@echo off
title OSRP - autostart
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup') + '\OSRP Server.lnk');" ^
  "$s.TargetPath = '%~dp0start-server.bat';" ^
  "$s.WorkingDirectory = '%~dp0';" ^
  "$s.WindowStyle = 7;" ^
  "$s.Save()"
if errorlevel 1 (
  echo Nije uspjelo.
) else (
  echo OSRP server ce se sada sam pokrenuti svaki put kad se upali racunalo.
  echo Za iskljucivanje pokreni remove-autostart.bat
)
pause
