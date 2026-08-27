@echo off
REM VERSION 2026.08.26-9
setlocal

REM ============================================================================
REM  Pull the latest scripts from GitHub, overwriting the copies in this folder.
REM
REM  To get THIS file in the first place:
REM
REM  curl.exe -sLo refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
REM
REM  Overwritten every time: the .ps1 and .bat scripts, README.md
REM  Never touched:          documents.ini, transfer.ini, sourcedocids.txt, session.txt,
REM                          anything in OutputRoot
REM
REM  documents.ini is yours. If you ever want a fresh default copy, rename the one
REM  you have out of the way and fetch it by hand:
REM
REM  curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/documents.ini
REM ============================================================================

set "B=https://raw.githubusercontent.com/kevinnassery/veeva/main"
set "D=%~dp0"

echo Refreshing from %B%
echo.

call :get login.bat
call :get Get-VaultSession.ps1
call :get probe.bat
call :get Probe-Vault.ps1
call :get Run-Documents.bat
call :get Invoke-VaultDocumentAction.ps1
call :get transfer.bat
call :get Transfer-VaultDocuments.ps1
call :get refresh.bat
call :get README.md

if not exist "%D%documents.ini" (
  echo.
  echo   NOTE: no documents.ini here. Fetch one with:
  echo         curl.exe -sLO %B%/documents.ini
)
if not exist "%D%transfer.ini" (
  echo.
  echo   NOTE: no transfer.ini here. Fetch one with:
  echo         curl.exe -sLO %B%/transfer.ini
)

echo.
echo Done.
goto :end

:get
curl.exe -sfLo "%D%%~1" "%B%/%~1"
if errorlevel 1 (echo   FAILED    %~1 & exit /b)
set "VER=?"
for /f "tokens=2 delims='" %%V in ('findstr /b /c:"$ScriptVersion = " "%D%%~1" 2^>nul') do set "VER=%%V"
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%D%%~1" 2^>nul') do set "VER=%%V"
echo   updated   %~1  [%VER%]
exit /b

:end
echo.
pause
endlocal
