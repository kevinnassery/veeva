@echo off
REM VERSION 2026.08.30-27
setlocal

REM ============================================================================
REM  Veeva Vault - read-only probe
REM
REM  There is NOTHING to edit in this file. It reads documents.ini for VaultDNS,
REM  SessionId and OutputRoot, exactly like Run-Documents.bat does.
REM
REM  This script CHANGES NOTHING. It only reads:
REM     who you are and your user id (File Staging folders are /u{user_id})
REM     what is in your File Staging root and user folder
REM     the document fields, and which are editable
REM     the document types, by label and by name
REM     the product records and their ids
REM     whether "Binder: No" has a working VQL equivalent in this vault
REM     how many documents the view's filters actually match
REM
REM  It writes probe-output.txt into OutputRoot. Paste that file back.
REM  It contains no password and no session id - but it does list document type,
REM  product and folder names, so read it before sending it anywhere.
REM ============================================================================

set "PS1=%~dp0Probe-Vault.ps1"
set "CFG=%~dp0documents.ini"

if not exist "%PS1%" (
  echo ERROR: Probe-Vault.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: documents.ini not found next to this .bat file.
  goto :end
)

set "VER="
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%~f0"') do set "VER=%%V"
echo Version: %VER%
echo Config : %CFG%
echo.
echo This is READ ONLY. Nothing in Vault is changed.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConfigFile "%CFG%" %*

:end
echo.
pause
endlocal
