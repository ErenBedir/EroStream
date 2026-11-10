@echo off
rem EroStream web - Windows installer. Runs install-web.ps1 next to this file,
rem or downloads it from GitHub when used on its own.
setlocal
set "PS1=%~dp0install-web.ps1"
if not exist "%PS1%" (
  set "PS1=%TEMP%\erostream-install-web.ps1"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/ErenBedir/EroStream/main/tool/windows/install-web.ps1' -OutFile '%TEMP%\erostream-install-web.ps1'"
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
if errorlevel 1 pause
endlocal
