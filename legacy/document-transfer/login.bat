@echo off
REM VERSION 2026.08.29-30
setlocal

REM ============================================================================
REM  Log in once. Caches the session in session.txt so probe.bat and
REM  Run-Documents.bat stop asking for a password on every run.
REM
REM     login.bat            log in, cache the session
REM     login.bat -Clear     delete session.txt
REM
REM  session.txt is a live token for your Vault account. Do not paste it into
REM  documents.ini and do not mail it. Delete it when you are done.
REM ============================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-VaultSession.ps1" -ConfigFile "%~dp0documents.ini" %*

echo.
pause
endlocal
