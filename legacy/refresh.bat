@echo off
REM VERSION 2026.08.30-23
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
REM  curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/documents.ini
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

REM  A run in progress reads its script file from this folder, and the parallel
REM  supervisor launches each worker from it - so replacing files mid-run means new
REM  workers running different code from the process that started them. The scripts
REM  drop a .run-*.lock here while they work.
set "BUSY="
for %%L in ("%D%.run-*.lock") do call :checklock "%%L"
if defined BUSY (
  if /i not "%~1"=="-force" (
    echo.
    echo   REFUSING TO REFRESH - a run is still going. Let it finish, or use:
    echo         refresh.bat -force
    goto :end
  )
  echo   -force given: refreshing over a running job.
  echo.
)

REM  Files from an earlier layout that nothing loads any more. Left in place they are
REM  just confusing - two scripts that look like they do the same job, one of them dead.
call :retire Transfer-VaultAttachments.ps1

echo Refreshing from %B%
echo.

call :get legacy/attachments/attachments.bat                     attachments.bat
call :get legacy/attachments/Sync-VaultAttachments.ps1           Sync-VaultAttachments.ps1
call :get legacy/attachments/validator.bat                      validator.bat
call :get legacy/attachments/Validate-VaultAttachments.ps1      Validate-VaultAttachments.ps1
call :get starting-cleanup.bat                            starting-cleanup.bat
call :get refresh.bat                                     refresh.bat
call :get README.md                                       README.md

if not exist "%D%attachments.ini" (
  echo.
  echo   NOTE: no attachments.ini here. Fetch one with:
  echo         curl.exe -sLO %B%/legacy/attachments/attachments.ini
)
REM  The standalone tools now live under legacy/ in the repo. They still land in this
REM  folder flat, so nothing on this machine moves. The unified vault tool replaces
REM  them one command at a time; until then these are what runs.

echo.
if defined SKEW (
  echo   WARNING: the files here are NOT all the same version. A download probably
  echo   failed above. Run refresh.bat again before running anything else - a mixed
  echo   set is worse than an old one.
) else (
  if defined FIRSTVER echo All files at version %FIRSTVER%.
)

echo.
echo Done.
goto :end

REM  %1 = path in the repo, %2 = file name to write here. The repo groups scripts
REM  into folders; this folder stays flat.
:get
curl.exe -sfL -o "%D%%~2" "%B%/%~1"
if errorlevel 1 (echo   FAILED    %~2 & set "SKEW=1" & exit /b)
set "VER=?"
for /f "tokens=2 delims='" %%V in ('findstr /b /c:"$ScriptVersion = " "%D%%~2" 2^>nul') do set "VER=%%V"
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%D%%~2" 2^>nul') do set "VER=%%V"
echo   updated   %~2  [%VER%]
REM  Each test is its own statement, NOT wrapped in parentheses: inside a block cmd
REM  expands %FIRSTVER% when it parses the whole block, which is before the set above
REM  has run - so the first file would always look like a mismatch.
if "%VER%"=="?" exit /b
if not defined FIRSTVER set "FIRSTVER=%VER%"
if not "%VER%"=="%FIRSTVER%" set "SKEW=1"
exit /b

:checklock
REM  A lock only means something if its process is still alive. A crash leaves the file
REM  behind, and making someone delete it by hand to get on with their day is a bad
REM  trade for a guard that is supposed to protect them.
set "LPID="
for /f "tokens=2 delims==" %%P in ('findstr /b /c:"pid=" "%~1"') do set "LPID=%%P"
if not defined LPID goto :stalelock
tasklist /FI "PID eq %LPID%" | findstr /i "powershell.exe" >nul
if errorlevel 1 goto :stalelock
set "BUSY=1"
echo     %~nx1  - pid %LPID% is still running
exit /b
:stalelock
echo   cleared stale lock %~nx1 ^(pid %LPID% is not running^)
del /q "%~1"
exit /b

:retire
if exist "%D%%~1" (
  del /q "%D%%~1"
  echo   removed   %~1  ^(no longer used^)
)
exit /b

:end
echo.
pause
endlocal
