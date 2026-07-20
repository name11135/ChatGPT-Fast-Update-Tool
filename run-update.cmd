@echo off
setlocal
set "SCRIPT=%~dp0refresh-chatgpt-fast.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ForceClose
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
  echo Update failed with exit code %EXIT_CODE%.
) else (
  echo ChatGPT Fast update completed.
)
pause
exit /b %EXIT_CODE%
