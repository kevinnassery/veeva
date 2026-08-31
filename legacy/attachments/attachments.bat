@echo off
REM VERSION 2026.08.30-34
setlocal

REM ============================================================================
REM  Veeva Vault - copy document attachments from one vault to another.
REM
REM  There is NOTHING to edit in this file. All settings live in attachments.ini.
REM
REM  Set Mode in attachments.ini:
REM     REPORT   = list every attachment and total the size. Moves nothing.
REM     TRANSFER = download each one and upload it to the target staging.
REM
REM     attachments.bat -Test               stop once 5 are reconciled
REM     attachments.bat -Test -TestCount 20 stop once 20 are
REM     attachments.bat -WhatIf             list what would move, move nothing
REM     attachments.bat -MaxDocuments 50    examine 50 documents, then stop
REM
REM  -Test is the one to use first. Most documents have no attachments, so a cap
REM  of 5 DOCUMENTS can reconcile nothing; -Test counts what was reconciled.
REM
REM  Re-running skips any attachment already recorded SUCCESS.
REM ============================================================================

set "PS1=%~dp0Sync-VaultAttachments.ps1"
set "CFG=%~dp0attachments.ini"

if not exist "%PS1%" (
  echo ERROR: Sync-VaultAttachments.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: attachments.ini not found next to this .bat file.
  goto :end
)

set "VER="
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%~f0"') do set "VER=%%V"
set "MODE="
for /f "usebackq tokens=2 delims==" %%A in (`findstr /i /r /c:"^ *Mode *=" "%CFG%"`) do set "MODE=%%A"
if defined MODE set "MODE=%MODE: =%"

echo Version: %VER%
echo Config : %CFG%
if defined MODE echo Mode   : %MODE%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%" %*

:end
echo.
pause
endlocal
