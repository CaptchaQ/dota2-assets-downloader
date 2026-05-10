@echo off
rem Double-click launcher for Start-DotaAssetsDownloader.ps1
rem - switches the console to UTF-8 so the EN/RU UI renders correctly
rem - cd's into the folder of this .cmd (so relative paths work no matter
rem   where Windows opens the cmd from)
rem - prefers PowerShell 7+ (pwsh.exe) and falls back to Windows PowerShell 5.1
rem - bypasses execution policy for this single invocation only
rem - keeps the window open after the script finishes (pause)

setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS_EXE=pwsh.exe"

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\Start-DotaAssetsDownloader.ps1" %*
set "RC=%ERRORLEVEL%"

echo.
echo --------------------------------------------------------
echo Exit code: %RC%
pause
endlocal & exit /b %RC%
