@echo off
REM VERSION 2026.09.02-11
setlocal

REM ============================================================================
REM  Veeva Vault - Library bulk action from a VQL query
REM
REM  There is NOTHING to edit in this file.
REM  All settings live in documents.ini, next to this script. Edit that, then
REM  double-click this file.
REM
REM  Set MODE in documents.ini to choose what happens:
REM     REPORT = run the query, write documents.csv, stop. Changes nothing.
REM     DRYRUN = everything UPDATE does except the write itself
REM     UPDATE = bulk-set the SetFields values on every matched document
REM     EXPORT = export every matched document to File Staging
REM
REM  Always start at REPORT and confirm documents.csv matches what the saved
REM  view shows in the Library before going further.
REM
REM  Anything you type after the .bat is passed through to the script, so
REM     Run-Documents.bat -WhatIf                  one-off dry run
REM     Run-Documents.bat -MaxDocuments 10         act on the first 10 only
REM     Run-Documents.bat -SamplePercent 10        a random 10% of the matches
REM     Run-Documents.bat -ExistingResults Restart rotate old reports, start fresh
REM  all work without editing anything. For a setting you want to keep, put it in
REM  documents.ini instead - there is no second copy here to fall out of sync.
REM
REM  If reports from an earlier run are already in OutputRoot, the script shows
REM  what they are and asks whether to continue or start fresh before it does
REM  anything. Starting fresh renames the old file, it never deletes it.
REM ============================================================================

set "PS1=%~dp0Invoke-VaultDocumentAction.ps1"
set "CFG=%~dp0documents.ini"

if not exist "%PS1%" (
  echo ERROR: Invoke-VaultDocumentAction.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: documents.ini not found next to this .bat file.
  goto :end
)

REM Pull MODE out of documents.ini only so we can echo it before starting.
REM The script parses documents.ini itself; this is a display convenience, not a
REM second source of configuration.
set "MODE="
for /f "usebackq tokens=2 delims==" %%A in (`findstr /i /r /c:"^ *MODE *=" "%CFG%"`) do set "MODE=%%A"
if defined MODE set "MODE=%MODE: =%"

set "VER="
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%~f0"') do set "VER=%%V"
echo Version: %VER%
echo Config : %CFG%
if defined MODE echo Mode   : %MODE%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%" %*

:end
echo.
pause
endlocal
