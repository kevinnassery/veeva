@echo off
REM VERSION 2026.08.30-16
setlocal

REM ============================================================================
REM  Veeva Vault - prove the target's attachments are the same files.
REM
REM  Reads attachments.ini and map.csv, the same two files the sync uses. It
REM  CHANGES NOTHING in either vault.
REM
REM  Mode in attachments.ini:
REM     DEEP = download both copies and hash them. Proves the bytes. Default.
REM     FAST = compare the MD5 Vault records on each side. No downloads.
REM
REM     validator.bat -Test              compare 5, then stop
REM     validator.bat -MaxDocuments 50   check 50 documents, then stop
REM     validator.bat -Workers 8         DEEP is bandwidth-bound; workers help
REM
REM  Verdicts per attachment, in validate-results.csv:
REM     MATCH              same name, same MD5
REM     MISMATCH           same name, DIFFERENT bytes
REM     MISSING_ON_TARGET  on the source, not on the target
REM     MISSING_ON_SOURCE  on the target, not on the source
REM     NO_CHECKSUM        FAST only - a side recorded no MD5; use DEEP
REM ============================================================================

set "PS1=%~dp0Validate-VaultAttachments.ps1"
set "CFG=%~dp0attachments.ini"

if not exist "%PS1%" (
  echo ERROR: Validate-VaultAttachments.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: attachments.ini not found next to this .bat file.
  goto :end
)

set "VER="
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%~f0"') do set "VER=%%V"
echo Version: %VER%
echo Config : %CFG%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%" %*

:end
echo.
pause
endlocal
