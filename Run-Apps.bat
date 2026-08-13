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
REM  SAMPLE is optional. Leave it empty to process every submission. Set it to a
REM  whole number 1-100 to process only that percentage of each application's
REM  submissions, picked at random - e.g. SAMPLE=10 spot-checks about a tenth of
REM  each app. The count rounds up, so every app still gets at least one.
REM  Set it here OR type -SamplePercent on the command line, not both - passing it
REM  twice is an error.
REM
REM  If reports from an earlier run already exist for any of these applications,
REM  you are asked ONCE - continue, or rotate them aside and start fresh - and the
REM  answer applies to the whole batch. Starting fresh renames, it never deletes.
REM
REM  Everything else (VaultDNS, fields, etc.) still comes from config.ini.
REM ============================================================================

set "MODE=DRYRUN"
set "SAMPLE="

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

set "SAMPLEARG="
if defined SAMPLE set "SAMPLEARG=-SamplePercent %SAMPLE%"

echo Applications file : %APPS%
echo Mode              : %MODE%
if defined SAMPLE echo Sample            : %SAMPLE%%% of each application
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Mode %MODE% -AppsFile "%APPS%" %SAMPLEARG% %*

:end
echo.
pause
endlocal
