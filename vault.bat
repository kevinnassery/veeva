@echo off
REM VERSION 2026.08.28-19
setlocal

REM ============================================================================
REM  Vault Kit. All settings live in vault.ini next to this file.
REM
REM     vault login            log in once, cache the sessions
REM     vault whoami           who is cached, and how old
REM     vault probe            read-only survey of each vault
REM     vault logout           delete the cached sessions
REM     vault help             every command
REM
REM  Anything after the command is passed through to PowerShell.
REM ============================================================================

set "PS1=%~dp0vault.ps1"
if not exist "%PS1%" (
  echo ERROR: vault.ps1 not found next to this .bat file.
  goto :end
)

set "VER="
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%~f0"') do set "VER=%%V"
echo vault %VER%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

:end
echo.
pause
endlocal
