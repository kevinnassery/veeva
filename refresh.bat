@echo off
setlocal

REM ============================================================================
REM  Pull the latest scripts from GitHub, overwriting the copies in this folder.
REM
REM  To get THIS file in the first place:
REM
REM  curl.exe -sLo refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
REM
REM  Overwritten every time:   the .ps1 and .bat scripts, README.md
REM  Downloaded only if absent: documents.ini  (your settings are never clobbered)
REM  Never touched:            sourcedocids.txt, and anything in OutputRoot
REM ============================================================================

set "B=https://raw.githubusercontent.com/kevinnassery/veeva/main"
set "D=%~dp0"

echo Refreshing from %B%
echo.

call :get probe.bat
call :get Probe-Vault.ps1
call :get Run-Documents.bat
call :get Invoke-VaultDocumentAction.ps1
call :get refresh.bat
call :get README.md

if exist "%D%documents.ini" (
  echo   keep      documents.ini  ^(already here - your settings^)
) else (
  call :get documents.ini
)

echo.
echo Done.
goto :end

:get
curl.exe -sfLo "%D%%~1" "%B%/%~1"
if errorlevel 1 (echo   FAILED    %~1) else (echo   updated   %~1)
exit /b

:end
echo.
pause
endlocal
