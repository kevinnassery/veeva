@echo off
setlocal

REM ============================================================================
REM  Veeva Vault RIM - Submissions Archive bulk import
REM
REM  Edit the four settings below, then double-click this file (or run it from
REM  a command prompt).
REM
REM  This wrapper NEVER writes to SOURCE_ROOT. Everything it produces - the
REM  manifest, the results CSV and the log - lands in OUTPUT_ROOT.
REM ============================================================================

REM --- Settings ---------------------------------------------------------------
REM  These mirror the CONFIG block at the top of Import-VaultSubmissions.ps1.
REM  Whatever you set here is passed on the command line and overrides the
REM  script's own values, so you only need to fill them in one place - here.

set VAULT_DNS=mycompany-rim.veevavault.com

REM Vault API version. Change this one value to move the whole script between releases.
set API_VERSION=v26.2

REM Optional: Vault's own export_results.csv from the Bulk Submission Export summary zip.
REM If set, the archive-to-submission mapping is read from it and you do not have to fill
REM in SubmissionId by hand. Leave blank if you do not have it.
set EXPORT_RESULTS=

REM Folder holding the bulk download. Layout: SOURCE_ROOT\<application>\<submission>.zip
set SOURCE_ROOT=D:\SubmissionDownloads

REM Where the manifest, results CSV and log get written. Must NOT be inside SOURCE_ROOT.
set OUTPUT_ROOT=D:\ImportRun

REM Mode:  MANIFEST = build the mapping sheet only
REM        DRYRUN   = validate everything, upload/import nothing
REM        IMPORT   = do it for real
set MODE=MANIFEST

REM ----------------------------------------------------------------------------

set PS1=%~dp0Import-VaultSubmissions.ps1
set MANIFEST=%OUTPUT_ROOT%\manifest.csv

set EXPORT_ARG=
if not "%EXPORT_RESULTS%"=="" set EXPORT_ARG=-ExportResultsCsv "%EXPORT_RESULTS%"

if not exist "%PS1%" (
  echo ERROR: Import-VaultSubmissions.ps1 not found next to this .bat file.
  goto :end
)

if /I "%MODE%"=="MANIFEST" (
  echo Building manifest from %SOURCE_ROOT% ...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" ^
    -VaultDNS "%VAULT_DNS%" -ApiVersion "%API_VERSION%" ^
    -SourceRoot "%SOURCE_ROOT%" -OutputRoot "%OUTPUT_ROOT%" %EXPORT_ARG% -GenerateManifest
  echo.
  echo Next: open "%MANIFEST%", fill in SubmissionId for each row,
  echo       then set MODE=DRYRUN in this file and run it again.
  goto :end
)

if not exist "%MANIFEST%" (
  echo ERROR: %MANIFEST% not found. Run this with MODE=MANIFEST first.
  goto :end
)

if /I "%MODE%"=="DRYRUN" (
  echo Dry run - no uploads, no imports ...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" ^
    -VaultDNS "%VAULT_DNS%" -ApiVersion "%API_VERSION%" ^
    -SourceRoot "%SOURCE_ROOT%" -OutputRoot "%OUTPUT_ROOT%" %EXPORT_ARG% ^
    -Manifest "%MANIFEST%" -WhatIf
  goto :end
)

if /I "%MODE%"=="IMPORT" (
  echo Importing for real. You will be prompted for your Vault credentials.
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" ^
    -VaultDNS "%VAULT_DNS%" -ApiVersion "%API_VERSION%" ^
    -SourceRoot "%SOURCE_ROOT%" -OutputRoot "%OUTPUT_ROOT%" %EXPORT_ARG% ^
    -Manifest "%MANIFEST%"
  goto :end
)

echo ERROR: MODE must be MANIFEST, DRYRUN or IMPORT (currently "%MODE%").

:end
echo.
pause
endlocal
