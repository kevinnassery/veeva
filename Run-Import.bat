@echo off
setlocal

REM ============================================================================
REM  Veeva Vault RIM - Submissions Archive bulk import
REM
REM  There is NOTHING to edit in this file.
REM  All settings live in config.ini, next to this script. Edit that, then
REM  double-click this file.
REM
REM  Set MODE in config.ini to choose what happens:
REM     MANIFEST = scan the download, write manifest.csv, stop
REM     DRYRUN   = resolve everything, upload and import nothing
REM     IMPORT   = do it for real
REM
REM  Anything you type after the .bat is passed through to the script, so
REM     Run-Import.bat -WhatIf              one-off dry run
REM     Run-Import.bat -SamplePercent 10    process a random 10% of the submissions
REM     Run-Import.bat -ExistingResults Restart   rotate old reports, start fresh
REM  all work without editing anything. For a setting you want to keep, put it in
REM  config.ini instead - there is no second copy here to fall out of sync.
REM
REM  If reports from an earlier run are already in OutputRoot, the script shows
REM  what they are and asks whether to continue or start fresh before it does
REM  anything. Starting fresh renames the old file, it never deletes it.
REM ============================================================================

set "PS1=%~dp0Import-VaultSubmissions.ps1"
set "CFG=%~dp0config.ini"

if not exist "%PS1%" (
  echo ERROR: Import-VaultSubmissions.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: config.ini not found next to this .bat file.
  goto :end
)

REM Pull MODE out of config.ini only so we can echo it before starting.
REM The script parses config.ini itself; this is a display convenience, not a
REM second source of configuration.
set "MODE="
for /f "usebackq tokens=2 delims==" %%A in (`findstr /i /r /c:"^ *MODE *=" "%CFG%"`) do set "MODE=%%A"
if defined MODE set "MODE=%MODE: =%"

echo Config : %CFG%
if defined MODE echo Mode   : %MODE%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%" %*

:end
echo.
pause
endlocal
