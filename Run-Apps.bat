@echo off
setlocal

REM ============================================================================
REM  Veeva Vault RIM - process MANY applications from apps.txt
REM
REM  Edit apps.txt (one application folder per line), set MODE below, then
REM  double-click this file. It runs the import for every application listed,
REM  writing each one's results to its own folder.
REM
REM     MANIFEST = list submissions, write manifest.csv per app, stop
REM     DRYRUN   = resolve every submission, import nothing
REM     IMPORT   = do it for real (asks you to confirm first)
REM
REM  Everything else (VaultDNS, fields, etc.) still comes from config.ini.
REM ============================================================================

set "MODE=DRYRUN"

set "PS1=%~dp0Process-Apps.ps1"
set "APPS=%~dp0apps.txt"

if not exist "%PS1%" (
  echo ERROR: Process-Apps.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%APPS%" (
  echo ERROR: apps.txt not found next to this .bat file.
  goto :end
)

echo Applications file : %APPS%
echo Mode              : %MODE%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Mode %MODE% -AppsFile "%APPS%" %*

:end
echo.
pause
endlocal
