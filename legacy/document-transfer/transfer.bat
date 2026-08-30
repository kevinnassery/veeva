@echo off
REM VERSION 2026.08.30-18
setlocal

REM ============================================================================
REM  Veeva Vault - copy document source files from one vault to another.
REM
REM  There is NOTHING to edit in this file. All settings live in transfer.ini.
REM
REM  For each id in sourcedocids.txt: download from the source vault, upload to
REM  the target vault's File Staging, delete the local copy. One file on disk at
REM  a time, so a 120GB set moves through a few GB of scratch space.
REM
REM  Each document lands in its own folder named for its source document id, so
REM  two files with the same name cannot overwrite each other.
REM
REM     transfer.bat -WhatIf            list what would move, move nothing
REM     transfer.bat -MaxDocuments 2    move two, then stop
REM
REM  Re-running skips anything already recorded SUCCESS.
REM ============================================================================

set "PS1=%~dp0Transfer-VaultDocuments.ps1"
set "CFG=%~dp0transfer.ini"

if not exist "%PS1%" (
  echo ERROR: Transfer-VaultDocuments.ps1 not found next to this .bat file.
  goto :end
)
if not exist "%CFG%" (
  echo ERROR: transfer.ini not found next to this .bat file.
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
