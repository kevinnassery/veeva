@echo off
REM VERSION 2026.08.26-13
setlocal

REM ============================================================================
REM  Pull the latest scripts from GitHub, overwriting the copies in this folder.
REM
REM  To get THIS file in the first place:
REM
REM  curl.exe -sLo refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
REM
REM  Overwritten every time: the .ps1 and .bat scripts, README.md
REM
REM  Downloads are pinned to a commit SHA. raw.githubusercontent.com caches the
REM  branch URL for five minutes and ignores no-cache, so pulling from /main can
REM  hand back the PREVIOUS version of a file - which looks exactly like a fix
REM  that did not work. A SHA-pinned URL is immutable and always current.
REM  Never touched:          documents.ini, transfer.ini, sourcedocids.txt, session.txt,
REM                          anything in OutputRoot
REM
REM  documents.ini is yours. If you ever want a fresh default copy, rename the one
REM  you have out of the way and fetch it by hand:
REM
REM  curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/documents.ini
REM ============================================================================

set "REPO=kevinnassery/veeva"
set "D=%~dp0"

REM One API call for the head commit. This endpoint returns the bare SHA and is
REM not behind the five-minute raw cache.
set "SHA="
for /f %%S in ('curl.exe -s -H "Accept: application/vnd.github.sha" https://api.github.com/repos/%REPO%/commits/main') do set "SHA=%%S"

echo %SHA%| findstr /r /c:"^[0-9a-f][0-9a-f]*$" >nul
if errorlevel 1 (
  echo   WARNING: could not read the head commit - falling back to the main branch.
  echo   Files may be up to five minutes out of date. Check the versions below.
  set "B=https://raw.githubusercontent.com/%REPO%/main"
) else (
  set "B=https://raw.githubusercontent.com/%REPO%/%SHA%"
  echo Commit : %SHA%
)

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
curl.exe -sfL -H "Cache-Control: no-cache" -H "Pragma: no-cache" -o "%D%%~1" "%B%/%~1"
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
