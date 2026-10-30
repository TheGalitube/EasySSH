@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EasySSH.ps1"
set "result=%ERRORLEVEL%"
if not "%result%"=="0" (
    echo.
    echo EasySSH exited with an error. Review the message above.
    pause
)
exit /b %result%
